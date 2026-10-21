import 'package:flutter/material.dart';

import 'models/syllabus.dart';
import 'screens/processing_screen.dart';
import 'screens/review_screen.dart';
import 'screens/upload_screen.dart';
import 'services/syllabus_extractor.dart';
import 'theme/app_theme.dart';

void main() => runApp(const SyllabusApp());

class SyllabusApp extends StatelessWidget {
  const SyllabusApp({super.key, this.extractor = const MockSyllabusExtractor()});

  /// Swap in the real LLM-backed extractor when it exists.
  final SyllabusExtractor extractor;

  // Step 2: extraction. On success it replaces itself with the review.
  Route<void> _processing(BuildContext context, SyllabusUpload upload) {
    final nav = Navigator.of(context);
    return MaterialPageRoute<void>(
      builder: (_) => ProcessingScreen(
        upload: upload,
        extractor: extractor,
        onDone: (events) =>
            nav.pushReplacement(_review(context, upload, events)),
      ),
    );
  }

  // Step 3: review, re-extract, choose destination, save.
  Route<void> _review(
    BuildContext context,
    SyllabusUpload upload,
    List<ExtractedEvent> events,
  ) {
    final nav = Navigator.of(context);
    return MaterialPageRoute<void>(
      builder: (_) => ReviewScreen(
        upload: upload,
        events: events,
        connected: const {SaveDestination.device},
        onReparse: (note) => nav.pushReplacement(
          _processing(context, upload.copyWith(hint: note)),
        ),
        // TODO: real sign-in for Google / Microsoft.
        onConnect: (destination) async {
          await Future<void>.delayed(const Duration(milliseconds: 900));
          return true;
        },
        // TODO: write to the device calendar or the linked account.
        onSave: (saved, destination) {
          nav.popUntil((route) => route.isFirst);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Saved ${saved.length} dates (mock).')),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Syllabus to Calendar',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: Builder(
        builder: (context) => UploadScreen(
          // TODO: replace with a real picker (e.g. file_picker, PDF only).
          onPickFile: () async => const PickedSyllabus(
            name: 'BIO_2310_Syllabus_Fall2026.pdf',
            sizeBytes: 421888,
          ),
          onExtract: (upload) =>
              Navigator.of(context).push(_processing(context, upload)),
        ),
      ),
    );
  }
}
