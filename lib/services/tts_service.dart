import 'package:flutter_tts/flutter_tts.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TtsState { playing, paused, stopped }

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  TtsState _state = TtsState.stopped;
  
  static const String _cacheKey = "cached_arabic_voices";

  String _currentFullText = "";
  Function(TtsState)? onStateChanged;
  Function? onCompletion;

  List<Map<String, String>> _cachedVoices = [];
  bool _isScanning = false;

  TtsService() {
    _initTts();
    _loadCachedVoices();
  }

  Future<void> _loadCachedVoices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? json = prefs.getString(_cacheKey);
      if (json != null) {
        final List<dynamic> decoded = jsonDecode(json);
        _cachedVoices = decoded.map((v) => Map<String, String>.from(v)).toList();
      }
    } catch (e) {
      print("Cache load error: $e");
    }
  }

  Future<void> _saveVoicesToCache(List<Map<String, String>> voices) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(voices));
    } catch (e) {
      print("Cache save error: $e");
    }
  }

  void _initTts() async {
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setSpeechRate(0.5); 
    await _flutterTts.setPitch(1.0);

    _flutterTts.setStartHandler(() {
      _state = TtsState.playing;
      onStateChanged?.call(_state);
    });

    // ملاحظة مهمة: عند الاستئناف بعد إيقاف مؤقت، يُطلق flutter_tts الحدث
    // "speak.onContinue" (وليس "speak.onStart"). كان هذا المعالج غير
    // مُسجَّل سابقاً، فتبقى حالتنا (_state) عالقة على "paused" فعلياً حتى
    // لو كان الصوت يُشغَّل بالفعل، مما يُفسد زر التشغيل/الإيقاف المؤقت في
    // كل مرة يُضغط بعدها (كان يُعيد تشغيل النص من البداية بدل إيقافه مؤقتاً).
    _flutterTts.setContinueHandler(() {
      _state = TtsState.playing;
      onStateChanged?.call(_state);
    });

    _flutterTts.setPauseHandler(() {
      _state = TtsState.paused;
      onStateChanged?.call(_state);
    });

    _flutterTts.setCancelHandler(() {
      _state = TtsState.stopped;
      onStateChanged?.call(_state);
    });

    _flutterTts.setCompletionHandler(() {
      _state = TtsState.stopped;
      onStateChanged?.call(_state);
      onCompletion?.call();
    });

    _flutterTts.setErrorHandler((msg) {
      _state = TtsState.stopped;
      onStateChanged?.call(_state);
      print("TTS Error: $msg");
    });
  }

  Future<void> setSpeed(double speed) async {
    double ttsSpeed = (speed * 0.5).clamp(0.0, 1.0);
    await _flutterTts.setSpeechRate(ttsSpeed);
  }

  /// أقصى عدد من الأصوات العربية نعرضها للمستخدم. تجربة سابقة كانت تجمع كل
  /// الأصوات من كل محركات TTS المثبتة على الجهاز (أحياناً عشرات الأصوات)،
  /// لكن معظمها إما أصوات شبكية غير مضمونة العمل أو أصوات محرك ثانوي لم
  /// تُختبر فعلياً، فكان المستخدم يجد قائمة طويلة جداً منها اثنان فقط
  /// يعملان فعلياً. الآن نكتفي بمحرك TTS الافتراضي للجهاز (وليس كل محرك
  /// مثبّت) ونعرض فقط أصواتاً تُعلمنا منصة أندرويد صراحةً أن بياناتها مُثبّتة
  /// على الجهاز (أي لن تفشل بصمت)، محدودة بأفضل 5 أصوات.
  static const int _maxVoices = 5;

  /// جلب أفضل 5 أصوات عربية تعمل فعلياً على محرك TTS الافتراضي للجهاز.
  Future<List<Map<String, String>>> getVoices({bool forceRefresh = false}) async {
    if (_cachedVoices.isNotEmpty && !forceRefresh) {
      // نبدأ فحصاً في الخلفية لتحديث الذاكرة المؤقتة دون تأخير الواجهة
      _backgroundScan();
      return _cachedVoices;
    }

    await _backgroundScan();
    return _cachedVoices;
  }

  Future<void> _backgroundScan() async {
    if (_isScanning) return;
    _isScanning = true;

    try {
      final List<Map<String, String>> found = await _scanArabicVoices();
      if (found.isNotEmpty) {
        _cachedVoices = found;
        _saveVoicesToCache(_cachedVoices);
        onStateChanged?.call(_state); // لتحديث الواجهة إن لزم
      }
    } catch (e) {
      print("Error fetching voices: $e");
    } finally {
      _isScanning = false;
    }
  }

  /// يفحص أصوات محرك TTS الحالي (الافتراضي) فقط، يستبعد أي صوت تُعلمنا
  /// المنصة أن بياناته غير مُثبّتة بعد (يفشل بصمت لو استُخدم)، ويُعيد أفضل
  /// [_maxVoices] أصوات مرتّبة بحيث تُفضَّل الأصوات التي تعمل دون اتصال
  /// بالإنترنت (أكثر موثوقية) والأعلى جودة أولاً.
  Future<List<Map<String, String>>> _scanArabicVoices() async {
    List<dynamic>? voices;
    try {
      voices = await _flutterTts.getVoices;
    } catch (e) {
      return [];
    }
    if (voices == null) return [];

    final List<Map<String, String>> candidates = [];
    final Set<String> seenNames = {};

    for (final voice in voices) {
      try {
        final map = Map<String, dynamic>.from(voice as Map);
        final String locale = map["locale"]?.toString() ?? "";
        final String name = map["name"]?.toString() ?? "";
        if (name.isEmpty || !locale.toLowerCase().startsWith("ar")) continue;
        if (!seenNames.add(name)) continue;

        bool requiresNetwork = false;
        int qualityRank = 0;
        if (Platform.isAndroid) {
          final String features = map["features"]?.toString() ?? "";
          // صوت غير مُثبّت فعلياً على الجهاز: استخدامه يفشل بصمت، نستبعده.
          if (features.contains("notInstalled")) continue;
          requiresNetwork = map["network_required"]?.toString() == "1";
          qualityRank = _qualityRank(map["quality"]?.toString());
        }

        String country = "";
        if (locale.contains("-")) {
          country = " (${locale.split('-').last.toUpperCase()})";
        } else if (locale.contains("_")) {
          country = " (${locale.split('_').last.toUpperCase()})";
        }

        candidates.add({
          "name": name,
          "locale": locale,
          "displayName": "العربية$country",
          "_offline": requiresNetwork ? "0" : "1",
          "_quality": qualityRank.toString(),
        });
      } catch (e) {}
    }

    candidates.sort((a, b) {
      final int offlineCompare = (b["_offline"] ?? "0").compareTo(a["_offline"] ?? "0");
      if (offlineCompare != 0) return offlineCompare;
      final int qualityCompare =
          int.parse(b["_quality"] ?? "0").compareTo(int.parse(a["_quality"] ?? "0"));
      if (qualityCompare != 0) return qualityCompare;
      return (a["displayName"] ?? "").compareTo(b["displayName"] ?? "");
    });

    return candidates.take(_maxVoices).map((v) {
      final copy = Map<String, String>.from(v);
      copy.remove("_offline");
      copy.remove("_quality");
      return copy;
    }).toList();
  }

  int _qualityRank(String? quality) {
    switch (quality) {
      case "very high":
        return 4;
      case "high":
        return 3;
      case "normal":
        return 2;
      case "low":
        return 1;
      case "very low":
        return 0;
      default:
        return 2;
    }
  }

  Future<void> setVoice(Map<String, String> voice) async {
    try {
      // ملاحظة مهمة: لا يجوز استدعاء setLanguage() بعد setVoice()، لأن
      // TextToSpeech على أندرويد يعيد ضبط الصوت تلقائياً إلى الصوت الافتراضي
      // لتلك اللغة عند استدعاء setLanguage()، مما كان يُلغي اختيار المستخدم
      // للصوت ويجعل التطبيق يقرأ دائماً بصوت واحد بغض النظر عن الاختيار.
      await _flutterTts.setVoice({
        "name": voice["name"]!,
        "locale": voice["locale"]!,
      });
    } catch (e) {
      // في حال فشل ضبط صوت بعينه، نتراجع إلى ضبط اللغة العربية فقط
      print("setVoice failed, falling back to language only: $e");
      try {
        await _flutterTts.setLanguage(voice["locale"] ?? "ar");
      } catch (_) {}
    }
  }

  /// يبدأ نطق [text]. إن كان [text] مطابقاً تماماً للنص الذي كان قيد النطق
  /// قبل استدعاء [pause] مباشرةً، فإن flutter_tts نفسه (وليس منطقنا هنا)
  /// يتعرّف داخلياً على أنه استئناف وليس بدءاً من جديد، ويكمل من نقطة
  /// التوقف تلقائياً (يتتبّع ذلك عبر tracked "currentText"/"pauseText"
  /// الخاصة به). لذلك لا نحتاج لتتبّع موضع التقدّم أو بناء نص متبقٍ يدوياً
  /// من جانبنا؛ فعل ذلك سابقاً كان يُنشئ حالتين منفصلتين للتقدّم (واحدة هنا
  /// وأخرى داخل المكوّن الإضافي) قد تتضاربان وتُسبّبان أخطاء استئناف/تشغيل
  /// عشوائية. كما أن استدعاء speak() هنا لنص *مختلف* أثناء تشغيل نص آخر
  /// يعمل بشكل صحيح تلقائياً (يُقاطعه ويبدأ الجديد فوراً) بفضل وضع
  /// QUEUE_FLUSH الافتراضي على مستوى النظام، فلا داعٍ لأي شرط يمنع الاستدعاء
  /// بناءً على الحالة الحالية.
  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    _currentFullText = text;
    await _flutterTts.speak(text);
  }

  Future<String?> exportAudio(String text, String fileName) async {
    try {
      Directory? tempDir;
      if (Platform.isAndroid) {
        tempDir = await getExternalStorageDirectory();
      }
      tempDir ??= await getApplicationDocumentsDirectory();

      String filePath = "${tempDir.path}/$fileName.wav";

      if (Platform.isAndroid) {
        await _flutterTts.synthesizeToFile(text, "$fileName.wav");

        File file = File(filePath);
        int retry = 0;
        while (!await file.exists() && retry < 10) {
          await Future.delayed(const Duration(milliseconds: 200));
          retry++;
        }

        return file.existsSync() ? filePath : null;
      }
      return null;
    } catch (e) {
      print("Export Error: $e");
      return null;
    }
  }

  /// يفتح إعدادات محرك النطق في نظام أندرويد ليتمكن المستخدم من تثبيت
  /// أصوات/لغات إضافية (لا يمكن للتطبيق تثبيت أصوات جديدة برمجياً،
  /// هذا قرار يتحكم به النظام فقط). يحل شق "إضافة" أصوات من المشكلة.
  ///
  /// يتطلب إضافة الحزمة التالية في pubspec.yaml:
  ///   android_intent_plus: ^4.0.3
  /// ثم إضافة الاستيراد:
  ///   import 'package:android_intent_plus/android_intent.dart';
  Future<void> openSystemVoiceDataSettings() async {
    if (!Platform.isAndroid) return;
    try {
      final AndroidIntent androidIntent = AndroidIntent(
        action: 'android.speech.tts.engine.INSTALL_TTS_DATA',
      );
      await androidIntent.launch();
    } catch (e) {
      print("Failed to open TTS settings: $e");
    }
  }

  Future<void> pause() async {
    await _flutterTts.pause();
    _state = TtsState.paused;
    onStateChanged?.call(_state);
  }

  /// يستأنف من نقطة التوقف. لا بد من تمرير نفس نص [_currentFullText]
  /// الأصلي (غير مبتور) إلى flutter_tts.speak حتى يتعرّف عليه داخلياً
  /// كاستئناف، لا كنص جديد (انظر توضيح [speak] أعلاه).
  Future<void> resume() async {
    if (_currentFullText.isEmpty) return;
    await _flutterTts.speak(_currentFullText);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
    _state = TtsState.stopped;
    onStateChanged?.call(_state);
  }

  TtsState get state => _state;
}
