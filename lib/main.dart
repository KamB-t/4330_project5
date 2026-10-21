import 'package:flutter/material.dart';

import 'models/syllabus.dart';
import 'screens/processing_screen.dart';
import 'screens/upload_screen.dart';
import 'services/syllabus_extractor.dart';
import 'theme/app_theme.dart';

void main() => runApp(const SyllabusApp());

class SyllabusApp extends StatelessWidget {
  const SyllabusApp({super.key, this.extractor = const MockSyllabusExtractor()});

  /// Swap in the real LLM-backed extractor when it exists.
  final SyllabusExtractor extractor;

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
          onExtract: (upload) => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ProcessingScreen(
                upload: upload,
                extractor: extractor,
                // TODO: replace with the step 3 review screen.
                onDone: (events) => Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      body: Center(
                        child: Text('Found ${events.length} dates. Review is next.'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
