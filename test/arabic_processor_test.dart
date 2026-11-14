import 'package:flutter_test/flutter_test.dart';
import 'package:iqra_anni/services/arabic_processor.dart';

void main() {
  group('ArabicProcessor Tests', () {
    test('Normalize Presentation Forms', () {
      expect(ArabicProcessor.cleanText('\uFEFB'), 'لا');
    });

    test('Fix Merged Words (Heuristic)', () {
      // "الولدالجميل" -> "الولد الجميل" (due to 'د' being non-joining followed by 'ال')
      expect(ArabicProcessor.cleanText('الولدالجميل'), 'الولد الجميل');
    });

    test('Clean text removes directional marks and invisible chars', () {
      expect(ArabicProcessor.cleanText('\u200E\u200Bالسلام'), 'السلام');
    });

    test('Normalize whitespace', () {
      expect(ArabicProcessor.cleanText('السلام   عليكم'), 'السلام عليكم');
    });

    test('Reshaping (Visual Check)', () {
      String text = 'السلام';
      String reshaped = ArabicProcessor.fixVisualOrder(text);
      // We expect standard connected Arabic characters. 
      // Length might change due to ligatures (Lam-Alef)
      expect(reshaped, isNotEmpty);
      expect(reshaped.codeUnitAt(0), isNot(text.codeUnitAt(0)));
    });
  });
}
