import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/file_service.dart';
import 'services/tts_service.dart';
import 'widgets/gemini_background.dart';
import 'database/db_helper.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'إقرأ عنّي',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.cyanAccent,
        useMaterial3: true,
      ),
      home: const ReaderPage(),
      locale: const Locale('ar', ''),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
    );
  }
}

class ReaderPage extends StatefulWidget {
  const ReaderPage({super.key});

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> with SingleTickerProviderStateMixin {
  final FileService _fileService = FileService();
  final TtsService _ttsService = TtsService();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  
  static const String _prefVoiceName = "selected_voice_name";

  List<String> _segments = [];
  int _currentSegmentIndex = -1;
  bool _isLoading = false;
  List<Map<String, String>> _arabicVoices = [];
  String? _selectedVoiceName;
  double _playbackSpeed = 1.0;

  List<Map<String, dynamic>> _library = [];
  List<Map<String, dynamic>> _favorites = [];
  int? _activeBookId;
  String _activeBookTitle = "";

  bool _isAutoPlay = true;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // تحميل الأصوات في الخلفية دون حجب أول إطار (async لا يحجب build أصلاً)،
    // بلا حاجة لتأخير اصطناعي كان موجوداً سابقاً فقط لإخفاء بطء فحص كل محرك
    // TTS مثبّت؛ بعد تبسيط الفحص لمحرك واحد لم يعد هذا التأخير ضرورياً.
    _loadVoices();
    _loadLibrary();
    _loadFavorites();

    _ttsService.onStateChanged = (state) {
      if (mounted) setState(() {});
    };

    // الانتقال التلقائي للمقطع التالي
    _ttsService.onCompletion = () {
      if (_isAutoPlay && _currentSegmentIndex < _segments.length - 1) {
        _handlePlayPause(_currentSegmentIndex + 1);
      }
    };
  }

  Future<void> _loadLibrary() async {
    final books = await _dbHelper.queryAllBooks();
    if (!mounted) return;
    setState(() => _library = books);
  }

  Future<void> _loadFavorites() async {
    final favs = await _dbHelper.queryAllFavorites();
    if (!mounted) return;
    setState(() => _favorites = favs);
  }

  Future<void> _loadVoices() async {
    final voices = await _ttsService.getVoices();
    final prefs = await SharedPreferences.getInstance();
    final savedVoiceName = prefs.getString(_prefVoiceName);
    if (!mounted) return;

    setState(() {
      _arabicVoices = voices;
      if (_arabicVoices.isNotEmpty) {
        // Try to find the saved voice, or default to the first one
        final voiceToSelect = _arabicVoices.any((v) => v["name"] == savedVoiceName)
            ? _arabicVoices.firstWhere((v) => v["name"] == savedVoiceName)
            : _arabicVoices[0];
            
        _selectedVoiceName = voiceToSelect["name"];
        _ttsService.setVoice(voiceToSelect);
      }
    });
  }

  Future<void> _pickAndLoadFile() async {
    setState(() => _isLoading = true);
    File? file = await _fileService.pickFile();
    if (file != null) {
      List<String> segments = await _fileService.extractText(file);
      if (segments.isNotEmpty) {
        String title = file.path.split(Platform.pathSeparator).last;
        int id = await _dbHelper.insertBook({
          'title': title,
          'path': file.path,
          'content': jsonEncode(segments),
          'lastSegmentIndex': 0,
        });
        if (!mounted) return;
        setState(() {
          _segments = segments;
          _currentSegmentIndex = 0;
          _activeBookId = id;
          _activeBookTitle = title;
          _isLoading = false;
        });
        _handlePlayPause(0);
        _loadLibrary();
        return;
      }
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  static List<String> _parseContent(String content) {
    return List<String>.from(jsonDecode(content));
  }

  Future<void> _loadBookFromLibrary(int bookId) async {
    setState(() => _isLoading = true);
    final bookData = await _dbHelper.getBookContent(bookId);
    if (bookData != null) {
      final segments = await compute(_parseContent, bookData['content'] as String);
      if (!mounted) return;
      setState(() {
        _segments = segments;
        _currentSegmentIndex = bookData['lastSegmentIndex'] ?? 0;
        _activeBookId = bookId;
        _activeBookTitle = bookData['title'] ?? "";
        _isLoading = false;
      });
      if (_segments.isNotEmpty) _handlePlayPause(_currentSegmentIndex);
    } else {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _handlePlayPause(int index) {
    if (_currentSegmentIndex == index && _ttsService.state == TtsState.playing) {
      _ttsService.pause();
    } else {
      setState(() => _currentSegmentIndex = index);
      _ttsService.speak(_segments[index]);
      if (_activeBookId != null) {
        _dbHelper.updatePosition(_activeBookId!, index);
      }
    }
  }

  // ميزة المشاركة والتصدير
  Future<void> _exportAndShare(String text, String title) async {
    var status = await Permission.storage.request();
    if (status.isGranted || true) { // simplified for demo
      setState(() => _isLoading = true);
      String fileName = "${title}_part_${DateTime.now().millisecondsSinceEpoch}";
      String? path = await _ttsService.exportAudio(text, fileName);
      setState(() => _isLoading = false);

      if (path != null) {
        if (!mounted) return;
        Share.shareXFiles([XFile(path)], text: 'استمع إلى هذا المقطع من: $title');
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل تصدير الملف الصوتي على هذا الجهاز')),
        );
      }
    }
  }

  // إضافة للمفضلة
  void _toggleFavorite(int index) async {
    await _dbHelper.insertFavorite({
      'bookId': _activeBookId,
      'segmentIndex': index,
      'text': _segments[index],
      'title': _activeBookTitle,
      'timestamp': DateTime.now().toIso8601String(),
    });
    _loadFavorites();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تمت الإضافة إلى المحفوظات')),
    );
  }

  @override
  Widget build(BuildContext context) {
    double audioIntensity = _ttsService.state == TtsState.playing ? 0.6 : 0.0;
    bool hasActiveBook = _segments.isNotEmpty;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(hasActiveBook ? _activeBookTitle : 'إقرأ عنّي',
          style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: hasActiveBook ? IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => setState(() {
            _segments = [];
            _activeBookId = null;
            _ttsService.stop();
          }),
        ) : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'تثبيت أصوات إضافية',
            onPressed: () => _ttsService.openSystemVoiceDataSettings(),
          ),
          _buildSpeedSelector(),
          _buildVoiceSelector(),
        ],
      ),
      body: Stack(
        children: [
          GeminiBackground(intensity: audioIntensity),
          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
                : !hasActiveBook
                    ? _buildHomeTabs()
                    : _buildSegmentList(),
          ),
        ],
      ),
      floatingActionButton: !hasActiveBook ? FloatingActionButton.extended(
        onPressed: _pickAndLoadFile,
        label: const Text('إضافة كتاب'),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.cyanAccent.withOpacity(0.2),
      ) : null,
      bottomNavigationBar: hasActiveBook ? _buildGlassyControlBar() : null,
    );
  }

  Widget _buildHomeTabs() {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          indicatorColor: Colors.cyanAccent,
          tabs: const [
            Tab(icon: Icon(Icons.library_books), text: 'المكتبة'),
            Tab(icon: Icon(Icons.bookmark), text: 'المحفوظات'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildLibraryView(),
              _buildFavoritesView(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSpeedSelector() {
    return PopupMenuButton<double>(
      icon: const Icon(Icons.speed),
      onSelected: (speed) {
        setState(() => _playbackSpeed = speed);
        _ttsService.setSpeed(speed);
      },
      itemBuilder: (context) => [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((s) {
        return PopupMenuItem(value: s, child: Text('${s}x'));
      }).toList(),
    );
  }

  Widget _buildLibraryView() {
    if (_library.isEmpty) return _buildEmptyState('المكتبة فارغة');
    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: _library.length,
      itemBuilder: (context, index) {
        final book = _library[index];
        return Card(
          color: Colors.white.withOpacity(0.05),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: ListTile(
            leading: const Icon(Icons.menu_book, color: Colors.cyanAccent),
            title: Text(book['title']),
            subtitle: Text('آخر مقطع: ${book['lastSegmentIndex']}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: () => _dbHelper.deleteBook(book['id']).then((_) => _loadLibrary()),
            ),
            onTap: () => _loadBookFromLibrary(book['id']),
          ),
        );
      },
    );
  }

  Widget _buildFavoritesView() {
    if (_favorites.isEmpty) return _buildEmptyState('لا توجد محفوظات');
    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: _favorites.length,
      itemBuilder: (context, index) {
        final fav = _favorites[index];
        return Card(
          color: Colors.white.withOpacity(0.05),
          child: ListTile(
            title: Text(fav['text'], maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text(fav['title']),
            trailing: IconButton(
              icon: const Icon(Icons.share, color: Colors.cyanAccent),
              onPressed: () => _exportAndShare(fav['text'], fav['title']),
            ),
            onTap: () {
              // تشغيل المقطع المحفوظ
              _ttsService.speak(fav['text']);
            },
            onLongPress: () => _dbHelper.deleteFavorite(fav['id']).then((_) => _loadFavorites()),
          ),
        );
      },
    );
  }

  Widget _buildVoiceSelector() {
    return PopupMenuButton<String>(
      tooltip: 'اختر الصوت',
      icon: const Icon(Icons.record_voice_over),
      onSelected: (val) async {
        if (val == "__refresh__") {
          _loadVoices();
          return;
        }
        setState(() => _selectedVoiceName = val);
        final voice = _arabicVoices.firstWhere((v) => v["name"] == val);
        _ttsService.setVoice(voice);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefVoiceName, val);
      },
      itemBuilder: (context) {
        List<PopupMenuEntry<String>> items = _arabicVoices.map((v) {
          bool isSelected = _selectedVoiceName == v["name"];
          return PopupMenuItem<String>(
            value: v["name"],
            child: Row(
              children: [
                if (isSelected) const Icon(Icons.check, size: 18, color: Colors.cyanAccent),
                if (isSelected) const SizedBox(width: 8),
                Expanded(child: Text(v["displayName"] ?? v["name"]!, style: TextStyle(fontSize: 12, color: isSelected ? Colors.cyanAccent : null))),
              ],
            ),
          );
        }).toList();

        items.insert(0, const PopupMenuItem<String>(
          value: "__refresh__",
          child: Row(
            children: [
              Icon(Icons.refresh, size: 18),
              SizedBox(width: 8),
              Text('تحديث قائمة الأصوات', style: TextStyle(fontSize: 12)),
            ],
          ),
        ));

        if (_arabicVoices.isEmpty) {
          items.add(const PopupMenuItem(enabled: false, child: Text('لا توجد أصوات عربية مثبتة')));
        }

        return items;
      },
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(child: Text(msg, style: const TextStyle(color: Colors.white38)));
  }

  Widget _buildSegmentList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      itemCount: _segments.length,
      itemBuilder: (context, index) {
        bool isCurrent = _currentSegmentIndex == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: isCurrent ? Colors.cyanAccent.withOpacity(0.1) : Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              ListTile(
                title: SelectableText( // تمكين التحديد اليدوي
                  _segments[index],
                  style: TextStyle(color: isCurrent ? Colors.cyanAccent : Colors.white70),
                ),
                leading: Icon(
                  isCurrent && _ttsService.state == TtsState.playing ? Icons.pause : Icons.play_arrow,
                  color: isCurrent ? Colors.cyanAccent : Colors.white24,
                ),
                onTap: () => _handlePlayPause(index),
              ),
              if (isCurrent)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.bookmark_add, size: 20),
                        onPressed: () => _toggleFavorite(index),
                      ),
                      IconButton(
                        icon: const Icon(Icons.share, size: 20),
                        onPressed: () => _exportAndShare(_segments[index], _activeBookTitle),
                      ),
                    ],
                  ),
                )
            ],
          ),
        );
      },
    );
  }

  Widget _buildGlassyControlBar() {
    TtsState state = _ttsService.state;
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 80,
          color: Colors.black.withOpacity(0.4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text('${_playbackSpeed}x', style: const TextStyle(color: Colors.cyanAccent)),
              IconButton(
                icon: Icon(state == TtsState.playing ? Icons.pause_circle : Icons.play_circle, size: 50, color: Colors.cyanAccent),
                onPressed: () => _handlePlayPause(_currentSegmentIndex),
              ),
              Switch(
                value: _isAutoPlay,
                activeColor: Colors.cyanAccent,
                onChanged: (val) => setState(() => _isAutoPlay = val),
              ),
              const Text('تلقائي', style: TextStyle(fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}
