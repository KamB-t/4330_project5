import 'dart:async';
import 'dart:typed_data';

import 'package:app5/models/syllabus.dart';
import 'package:app5/services/syllabus_extractor.dart';

/// Test-only stand-ins. Nothing here ships in the app.

/// Returns a small in-memory "PDF" without opening a file dialog.
Future<PickedSyllabus?> fakePickFile() async {
  final bytes = Uint8List.fromList('%PDF-1.4 test'.codeUnits);
  return PickedSyllabus(
    name: 'test_syllabus.pdf',
    sizeBytes: bytes.length,
    bytes: bytes,
  );
}

/// Never finishes, so a test can stay on the processing screen.
class PendingExtractor implements SyllabusExtractor {
  const PendingExtractor();

  @override
  Stream<ExtractionUpdate> extract(SyllabusUpload upload) =>
      StreamController<ExtractionUpdate>().stream;
}
