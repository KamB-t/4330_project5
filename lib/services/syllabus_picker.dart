import 'package:file_picker/file_picker.dart';

import '../models/syllabus.dart';

/// Opens the system file picker (PDF only). Returns null if the user cancels
/// and throws [SyllabusFileException] for a file we can't use.
Future<PickedSyllabus?> pickSyllabusFile() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['pdf'],
    withData: true, // required on web, where there is no file path
  );
  if (result == null || result.files.isEmpty) return null;

  final file = result.files.single;
  final bytes = file.bytes;
  if (bytes == null) {
    throw const SyllabusFileException(
      'Could not read that file. Please try another PDF.',
    );
  }
  if (bytes.length > maxSyllabusBytes) {
    throw const SyllabusFileException(
      'That file is over 5 MB. Please choose a smaller PDF.',
    );
  }
  // Real PDFs start with "%PDF-".
  final looksLikePdf =
      bytes.length >= 5 && String.fromCharCodes(bytes.sublist(0, 5)) == '%PDF-';
  if (!looksLikePdf) {
    throw const SyllabusFileException('That file does not look like a PDF.');
  }
  return PickedSyllabus(name: file.name, sizeBytes: bytes.length, bytes: bytes);
}
