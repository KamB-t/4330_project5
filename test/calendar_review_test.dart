import 'dart:async';

import 'package:app5/models/syllabus.dart';
import 'package:app5/screens/review_screen.dart';
import 'package:app5/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('connect Google then save selected events once while busy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final completion = Completer<void>();
    var connects = 0;
    var saves = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: ReviewScreen(
          upload: SyllabusUpload(
            file: const PickedSyllabus(name: 'syllabus.pdf', sizeBytes: 1),
            semesterStart: DateTime(2026, 8, 20),
            timeZone: 'Central (CT)',
          ),
          events: [
            ExtractedEvent(
              id: 'exam',
              title: 'Final',
              type: EventType.exam,
              date: DateTime(2026, 12, 15),
              course: 'CSC 4330',
            ),
          ],
          connected: const {SaveDestination.device},
          onReparse: (_) {},
          onConnect: (destination) async {
            expect(destination, SaveDestination.google);
            connects++;
            return true;
          },
          onSave: (events, destination) async {
            expect(destination, SaveDestination.google);
            expect(events.single.id, 'exam');
            saves++;
            await completion.future;
          },
        ),
      ),
    );
    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Google Calendar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Connect').first);
    await tester.pumpAndSettle();
    expect(connects, 1);
    await tester.tap(find.text('Use Google Calendar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add 1 date to Google Calendar'));
    await tester.pump();
    expect(find.text('Saving dates…'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Saving dates…'),
          )
          .onPressed,
      isNull,
    );
    expect(saves, 1);
    completion.complete();
    await tester.pumpAndSettle();
    expect(find.text('Add 1 date to Google Calendar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
