import 'package:intl/intl.dart' as intl;
import 'package:arabic_reshaper/arabic_reshaper.dart';

class ArabicProcessor {
  static final _reshaper = ArabicReshaper();

  /// Cleans and prepares text for TTS or Display.
  /// Standardizes Arabic characters to Logical Order and standard Unicode range,
  /// while resolving word boundary / merged word issues ("دمج الكلمات").
  static String cleanText(String input) {
    if (input.isEmpty) return "";

    String result = input;

    // ملاحظة: كانت هناك خطوة سابقة تحاول تخمين حدود الكلمات بالاعتماد على
    // "شكل" الحرف (منعزل/نهائي مقابل مبدئي/متوسط) ضمن أشكال العرض
    // (Presentation Forms). هذا خاطئ لغوياً: حروف مثل (ا د ذ ر ز و ة ى)
    // لا تتصل بما بعدها حتى **داخل الكلمة نفسها** (مثال: "الدرس"، "بارد"،
    // "دالة"، "زالت")، فكانت هذه الخطوة تُدخل مسافة خاطئة في منتصف عشرات
    // الكلمات الاعتيادية وتفصل الحروف عنها. حدود الكلمات الحقيقية تُضبط
    // أصلاً بشكل صحيح أثناء الاستخراج من PDF عبر دمج كلمات كل سطر
    // (wordCollection) بمسافات حقيقية بينها في file_service.dart، لذا تمت
    // إزالة هذا التخمين والاكتفاء بتطبيع الشكل الحرفي فقط أدناه.

    // 1. Normalize Arabic Presentation Forms (A & B) to standard Arabic range
    result = _normalizePresentationForms(result);

    // 2. Handle common Ligatures
    final Map<String, String> ligatures = {
      '\uFEFB': 'لا',
      '\uFEFC': 'لا',
      '\uFEF7': 'لأ',
      '\uFEF8': 'لأ',
      '\uFEF9': 'لإ',
      '\uFEFA': 'لإ',
      '\uFEF5': 'لآ',
      '\uFEF6': 'لآ',
    };
    ligatures.forEach((key, value) {
      result = result.replaceAll(key, value);
    });

    // 3. Remove Directional marks and other invisible characters
    result = result.replaceAll(RegExp(r'[\u200e\u200f\u202a-\u202e\u200b\ufeff]'), '');

    // 4. Smart Word Splitting on standard Unicode Arabic text
    result = _fixMergedWords(result);

    // 5. Normalize whitespace
    result = result.replaceAll(RegExp(r'\s+'), ' ');

    return result.trim();
  }

  /// Fixes cases where words are merged due to extraction errors.
  static String _fixMergedWords(String input) {
    if (input.isEmpty) return "";

    String result = input;

    const nonJoining = r'[ادذرزؤوآأإءةى]';
    const allArabic = r'[\u0621-\u064A\u0671-\u06D3]';

    // 1. Taa Marbouta (ة), Alef Maksura (ى), or Tanween (ً ٍ ٌ) followed by ANY Arabic letter
    result = result.replaceAllMapped(
      RegExp(r'([ةى\u064B\u064C\u064D])(' + allArabic + r')'),
      (m) => '${m[1]} ${m[2]}',
    );

    // 2. Non-joining character followed by "ال" (Definite Article) or prefix like "بال", "فال", "كال", "لل"
    result = result.replaceAllMapped(
      RegExp('($nonJoining)((?:[وبفك]?ال|لل)' + allArabic + r')'),
      (m) => '${m[1]} ${m[2]}',
    );

    // 3. Non-joining character followed by common particles / prepositions / pronouns / verbs
    const commonStarters = r'(?:في|من|عن|على|إلى|مع|حتى|منذ|نحو|تحت|فوق|بين|أمام|خلف|أن|إن|أنه|إنها|أنهم|كان|كانت|كانوا|يكون|تكون|هذا|هذه|ذلك|تلك|الذين|التي|الذي|قد|لم|لن|سوف|ما|لا|أو|ثم|بل|حيث|عند|غير|سوى|هو|هي|هم|نحن|أنا|أنت|قال|قالت|قالوا|يقول|تقول|عبد)';
    result = result.replaceAllMapped(
      RegExp('($nonJoining)($commonStarters)(?=$allArabic|\\s|\$)'),
      (m) => '${m[1]} ${m[2]}',
    );

    // 4. Non-joining character followed by word starting with Alef with Hamza (أ, إ, آ)
    result = result.replaceAllMapped(
      RegExp('($nonJoining)([أإآ]' + allArabic + r'{2,})'),
      (m) => '${m[1]} ${m[2]}',
    );

    // 5. Separate numbers and Arabic letters
    result = result.replaceAllMapped(
      RegExp(r'([' + allArabic + r'])([0-9\u0660-\u0669])'),
      (m) => '${m[1]} ${m[2]}',
    );
    result = result.replaceAllMapped(
      RegExp(r'([0-9\u0660-\u0669])([' + allArabic + r'])'),
      (m) => '${m[1]} ${m[2]}',
    );

    return result;
  }

  /// Normalizes presentation forms to the standard Arabic block (U+0600)
  static String _normalizePresentationForms(String input) {
    StringBuffer buffer = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      int code = input.codeUnitAt(i);

      // Mapping for common Presentation Forms B (U+FE70 - U+FEFF)
      if (code >= 0xFE70 && code <= 0xFEFF) {
        buffer.write(_mapPresentationFormB(code));
      }
      // Mapping for Presentation Forms A (U+FB50 - U+FDFF)
      else if (code >= 0xFB50 && code <= 0xFDFF) {
        buffer.write(_mapPresentationFormA(code));
      } else {
        buffer.write(String.fromCharCode(code));
      }
    }
    return buffer.toString();
  }

  static String _mapPresentationFormB(int code) {
    if (code >= 0xFE80 && code <= 0xFE88) return 'ء';
    if (code >= 0xFE89 && code <= 0xFE8C) return 'ئ';
    if (code >= 0xFE8D && code <= 0xFE8E) return 'ا';
    if (code >= 0xFE8F && code <= 0xFE92) return 'ب';
    if (code >= 0xFE93 && code <= 0xFE94) return 'ة';
    if (code >= 0xFE95 && code <= 0xFE98) return 'ت';
    if (code >= 0xFE99 && code <= 0xFE9C) return 'ث';
    if (code >= 0xFE9D && code <= 0xFEA0) return 'ج';
    if (code >= 0xFEA1 && code <= 0xFEA4) return 'ح';
    if (code >= 0xFEA5 && code <= 0xFEA8) return 'خ';
    if (code >= 0xFEA9 && code <= 0xFEAA) return 'د';
    if (code >= 0xFEAB && code <= 0xFEAC) return 'ذ';
    if (code >= 0xFEAD && code <= 0xFEAE) return 'ر';
    if (code >= 0xFEAF && code <= 0xFEB0) return 'ز';
    if (code >= 0xFEB1 && code <= 0xFEB4) return 'س';
    if (code >= 0xFEB5 && code <= 0xFEB8) return 'ش';
    if (code >= 0xFEB9 && code <= 0xFEBC) return 'ص';
    if (code >= 0xFEBD && code <= 0xFEC0) return 'ض';
    if (code >= 0xFEC1 && code <= 0xFEC4) return 'ط';
    if (code >= 0xFEC5 && code <= 0xFEC8) return 'ظ';
    if (code >= 0xFEC9 && code <= 0xFECC) return 'ع';
    if (code >= 0xFECD && code <= 0xFED0) return 'غ';
    if (code >= 0xFED1 && code <= 0xFED4) return 'ف';
    if (code >= 0xFED5 && code <= 0xFED8) return 'ق';
    if (code >= 0xFED9 && code <= 0xFEDC) return 'ك';
    if (code >= 0xFEDD && code <= 0xFEE0) return 'ل';
    if (code >= 0xFEE1 && code <= 0xFEE4) return 'م';
    if (code >= 0xFEE5 && code <= 0xFEE8) return 'ن';
    if (code >= 0xFEE9 && code <= 0xFEEC) return 'ه';
    if (code >= 0xFEED && code <= 0xFEEE) return 'و';
    if (code >= 0xFEEF && code <= 0xFEF0) return 'ى';
    if (code >= 0xFEF1 && code <= 0xFEF4) return 'ي';
    return String.fromCharCode(code);
  }

  static String _mapPresentationFormA(int code) {
    if (code == 0xFDFA) return 'صلى الله عليه وسلم';
    if (code == 0xFDFB) return 'جل جلاله';
    return String.fromCharCode(code);
  }

  /// Uses BiDi algorithm and Reshaper to ensure text is correct for display/TTS.
  static String fixVisualOrder(String text) {
    if (text.isEmpty) return "";
    String reshaped = _reshaper.reshape(text);
    return reshaped;
  }

  static bool isArabic(String text) {
    return intl.Bidi.detectRtlDirectionality(text);
  }
}
