import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app5/main.dart';

import 'test_doubles.dart';

void main() {
  testWidgets('History records submissions and preserves the upload form', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SyllabusApp(
        extractor: PendingExtractor(),
        pickFile: fakePickFile,
      ));
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('No uploads yet'), findsOneWidget);
    await tester.tap(find.text('Upload a syllabus'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose a PDF'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select a date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Extract dates'));
    await tester.pump();
    // Return during processing; the submission still belongs in history.
    final context = tester.element(find.byType(Navigator).first);
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('No uploads yet'), findsNothing);
    expect(find.text('test_syllabus.pdf'), findsOneWidget);
    expect(find.text('Extract again'), findsOneWidget);
    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();
    expect(find.text('test_syllabus.pdf'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('Extract is disabled until a file and date are set', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SyllabusApp(
        extractor: PendingExtractor(),
        pickFile: fakePickFile,
      ));

    expect(find.text('Add your syllabus'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    await tester.tap(find.text('Choose a PDF'));
    await tester.pump();

    expect(find.text('test_syllabus.pdf'), findsOneWidget);
  });
}
