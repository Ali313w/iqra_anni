import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:docx_to_text/docx_to_text.dart';
import 'package:file_picker/file_picker.dart';
import 'arabic_processor.dart';

class FileService {
  Future<File?> pickFile() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx'],
        // نطلب البيانات مباشرة كخطة احتياطية: بعض مزوّدي الملفات (خصوصاً
        // خدمات التخزين السحابي مثل Drive) لا يوفرون "path" حقيقياً على
        // القرص، فكان الكتاب يفشل في الفتح دون أي رسالة توضّح السبب.
        withData: true,
      );
    } catch (e) {
      debugPrint("File pick error: $e");
      return null;
    }

    if (result == null || result.files.isEmpty) return null;
    final PlatformFile picked = result.files.single;

    // نتحقق من أن الملف على "path" له محتوى فعلي (حجم أكبر من صفر) قبل
    // الاعتماد عليه. بعض مزوّدي الملفات (خصوصاً عبر SAF/التخزين السحابي)
    // يعيدون مساراً صالحاً ظاهرياً لملف نسخة مؤقتة فشل نسخ محتواه فعلياً،
    // فينتهي الملف بحجم صفر بايت، وكان هذا يُظهر خطأ "ملف فارغ" لملفات هي
    // في الحقيقة سليمة تماماً. في هذه الحالة نلجأ لاستخدام "bytes" (التي
    // طلبناها بـ withData: true تحديداً كخطة احتياطية) بدلاً من "path".
    if (picked.path != null && picked.path!.isNotEmpty) {
      final File pathFile = File(picked.path!);
      try {
        if (await pathFile.exists() && await pathFile.length() > 0) {
          return pathFile;
        }
      } catch (e) {
        debugPrint("Path file check error: $e");
      }
    }

    // لا يوجد مسار حقيقي (أو كان فارغاً)؛ نكتب البيانات إلى ملف مؤقت لضمان
    // نجاح فتح الكتاب دائماً بدلاً من إخفاق صامت أو خطأ "ملف فارغ" زائف.
    if (picked.bytes != null && picked.bytes!.isNotEmpty) {
      try {
        final Directory tempDir = await getTemporaryDirectory();
        final String safeName =
            picked.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
        final File tempFile = File(
            '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_$safeName');
        await tempFile.writeAsBytes(picked.bytes!);
        return tempFile;
      } catch (e) {
        debugPrint("Temp file write error: $e");
        return null;
      }
    }

    return null;
  }

  Future<List<String>> extractText(File file) async {
    final String extension = file.path.split('.').last.toLowerCase();
    Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (e) {
      debugPrint("File read error: $e");
      return [
        "تعذر فتح هذا الملف. تأكد من أنه غير تالف وأن التطبيق يملك صلاحية الوصول إليه."
      ];
    }

    // ننقل الاستخراج والتنظيف بالكامل إلى isolate منفصل عبر compute() بدلاً
    // من تنفيذه على الخيط الرئيسي (كما كان سابقاً، حيث كان معالجة النص فقط
    // تُنقل لـ isolate بعد أن يكون تحليل PDF/DOCX الثقيل قد جمّد الواجهة
    // بالفعل على الخيط الرئيسي). الكتب الكبيرة (مئات الصفحات) كانت تُجمّد
    // التطبيق لثوانٍ طويلة أثناء الاستخراج، وهو ما يُشعر المستخدم بالبطء
    // العام، بل وقد يتسبب بتوقف النظام عن الاستجابة عند فتح كتاب كبير بما
    // يبدو وكأن الكتاب "فشل في الفتح".
    try {
      return await compute(_extractAndProcess, _ExtractRequest(bytes, extension));
    } catch (e) {
      debugPrint("Extraction isolate error: $e");
      return ["حدث خطأ غير متوقع أثناء معالجة الملف."];
    }
  }
}

/// حمولة الطلب المرسلة إلى isolate الاستخراج (يجب أن تكون قابلة للإرسال
/// بين الـ isolates، لذا تقتصر على بيانات بسيطة فقط).
class _ExtractRequest {
  final Uint8List bytes;
  final String extension;
  const _ExtractRequest(this.bytes, this.extension);
}

/// نقطة الدخول التي تُنفَّذ كاملةً داخل isolate خلفي: تفكيك الملف، تنظيف
/// النص عربياً، وتقسيمه إلى مقاطع. يجب أن تبقى دالة top-level (وليست
/// closure أو method) لتصلح كوسيطة لـ compute().
///
/// ملاحظة مهمة حول استخراج النص العربي من PDF (تم التحقق تجريبياً وليس
/// فقط بالرجوع لكود المكتبة المصدري): جربنا نهجاً سابقاً كان يبني نص كل
/// سطر يدوياً من TextLine.wordCollection (قائمة "كلمات" Syncfusion). تبيّن
/// عبر اختبار فعلي على ملفات PDF عربية حقيقية (مُصدَّرة من متصفح بعرض RTL
/// سليم، وهو ما يحاكي كيف تُصدِّر معظم البرامج الحقيقية كملفات Word/المتصفح
/// PDFات العربية) أن هذا النهج **خاطئ جذرياً**: كل "كلمة" في wordCollection
/// غالباً ما تكون **حرفاً واحداً فقط** (بسبب الأشكال السياقية/العرضية لكل
/// حرف عربي)، وترتيبها في القائمة هو الترتيب البصري من اليسار لليمين على
/// الصفحة (يعني آخر كلمة في الجملة العربية تظهر أولاً في القائمة). دمج هذه
/// "الكلمات" بترتيبها كما وردت كان يُنتج نصاً مبعثراً ومفتتاً تماماً
/// (بالضبط أعراض المشكلة المُبلَّغ عنها).
///
/// بالمقابل، تبيّن أن TextLine.text (وهو نص السطر الكامل الذي تُعيد
/// المكتبة ترتيبه داخلياً عبر خوارزمية Bidi خاصة بها) يُعطي في الغالبية
/// العظمى من الحالات ترتيب كلمات صحيحاً تماماً (يطابق ترتيب القراءة
/// المنطقي للنص الأصلي) طالما بقي السطر بصرياً سطراً واحداً بدون تبديل
/// اتجاه معقّد (كنص عربي يتخلله رمز لاتيني في منتصف سطر ملتفّ/متعدد الأسطر
/// المرئية لنفس الفقرة، وهي حالة نادرة قد تُسبب أحياناً انعكاس ترتيب أجزاء
/// السطر أو انفصال حرف منفرد). لذلك اعتمدنا TextLine.text كمصدر أساسي بعد
/// ترتيب الأسطر عمودياً، مع تمرير الناتج عبر ArabicProcessor لتطبيع أشكال
/// العرض (Presentation Forms) وإصلاح حالات الدمج المتبقية.
List<String> _extractAndProcess(_ExtractRequest request) {
  // ملف بحجم صفر بايت فعلياً (نادر بعد إصلاح pickFile، لكن ممكن لملف تالف
  // فعلاً على القرص). PdfDocument يتحقق فقط من أن inputBytes ليست null وليس
  // من أنها غير فارغة، فتمرير قائمة فارغة يتسبب بخطأ داخلي غامض بدل رسالة
  // واضحة، لذا نلتقط هذه الحالة صراحةً هنا.
  if (request.bytes.isEmpty) {
    return ["هذا الملف فارغ أو تعذّرت قراءة محتواه، الرجاء اختيار ملف آخر."];
  }

  String rawText;
  try {
    if (request.extension == 'pdf') {
      rawText = _extractFromPdfBytes(request.bytes);
    } else if (request.extension == 'docx') {
      rawText = _extractFromDocxBytes(request.bytes);
    } else {
      return ["صيغة الملف غير مدعومة. الصيغ المدعومة حالياً هي PDF وWord (docx) فقط."];
    }
  } catch (e) {
    final String message = e.toString().toLowerCase();
    if (message.contains('password') || message.contains('encrypt')) {
      return ["هذا الملف محمي بكلمة مرور، ولا يمكن للتطبيق قراءته في الوقت الحالي."];
    }
    return ["تعذر استخراج النص من هذا الملف، قد يكون تالفاً أو بصيغة غير مدعومة بالكامل."];
  }

  if (rawText.trim().isEmpty) {
    return [
      "لم يتم العثور على نص قابل للقراءة في هذا الملف. قد يكون كتاباً ممسوحاً ضوئياً (صوراً فقط) دون طبقة نص، وهذه الحالة غير مدعومة حالياً."
    ];
  }

  final String cleaned = ArabicProcessor.cleanText(rawText);
  final List<String> segments = cleaned
      .split(RegExp(r'(?<=[.!?؟])\s+|\n+'))
      .map((s) => s.trim())
      .where((s) => s.length > 5)
      .toList();

  return segments.isNotEmpty ? segments : ["لم يتم العثور على نص قابل للقراءة."];
}

String _extractFromPdfBytes(Uint8List bytes) {
  final PdfDocument document = PdfDocument(inputBytes: bytes);
  try {
    final PdfTextExtractor extractor = PdfTextExtractor(document);
    final StringBuffer fullText = StringBuffer();

    for (int i = 0; i < document.pages.count; i++) {
      List<TextLine> lines;
      try {
        lines = extractor.extractTextLines(startPageIndex: i);
      } catch (e) {
        // نتجاهل صفحة واحدة تسبب خطأ استخراج ونكمل بقية صفحات الكتاب بدلاً
        // من إفشال استخراج الكتاب كاملاً بسبب صفحة واحدة معطوبة.
        continue;
      }

      // ترتيب الأسطر عمودياً من الأعلى إلى الأسفل
      lines.sort((a, b) => a.bounds.top.compareTo(b.bounds.top));

      for (final line in lines) {
        final String text = line.text.trim();
        if (text.isEmpty) continue;
        fullText.writeln(text);
      }
    }

    return fullText.toString();
  } finally {
    document.dispose();
  }
}

String _extractFromDocxBytes(Uint8List bytes) {
  return docxToText(bytes);
}
