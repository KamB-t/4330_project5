import 'package:flutter/material.dart';

import 'screens/upload_screen.dart';
import 'theme/app_theme.dart';

void main() => runApp(const SyllabusApp());

class SyllabusApp extends StatelessWidget {
  const SyllabusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Syllabus to Calendar',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: UploadScreen(
        // TODO: replace with a real picker (e.g. file_picker, PDF only).
        onPickFile: () async => const PickedSyllabus(
          name: 'BIO_2310_Syllabus_Fall2026.pdf',
          sizeBytes: 421888,
        ),
        onExtract: (upload) {
          // TODO: send to the extraction step.
        },
      ),
    );
  }
}
