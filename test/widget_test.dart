// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:iqra_anni/main.dart';

void main() {
  // sqflite يحتاج قناة منصة حقيقية (أندرويد/iOS) غير متوفرة أثناء
  // flutter test؛ نستخدم تطبيق sqflite_common_ffi (قائم على SQLite مباشرة)
  // بدلاً منها حصراً في بيئة الاختبار.
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('App launches and shows the empty-library home screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    // نستخدم pump بمهلة بدل pumpAndSettle لأن الخلفية المتحركة (شادر مستمر)
    // لا "تستقر" أبداً بتصميمها.
    await tester.pump(const Duration(seconds: 1));

    // بدون كتاب نشط، يجب أن يظهر زر إضافة كتاب.
    expect(find.text('إضافة كتاب'), findsOneWidget);
  });
}
