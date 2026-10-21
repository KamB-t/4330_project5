import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app5/main.dart';

void main() {
  testWidgets('Extract is disabled until a file and date are set',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SyllabusApp());

    expect(find.text('Add your syllabus'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    await tester.tap(find.text('Choose a PDF'));
    await tester.pump();

    expect(find.text('BIO_2310_Syllabus_Fall2026.pdf'), findsOneWidget);
  });
}
