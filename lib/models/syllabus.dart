import 'dart:typed_data';

/// Largest syllabus we accept. Keep in sync with MAX_FILE_BYTES in the Worker.
const int maxSyllabusBytes = 5 * 1024 * 1024;

/// Thrown by the file picker with a message that is safe to show the user.
class SyllabusFileException implements Exception {
  const SyllabusFileException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// A syllabus the user has selected. [bytes] is held in memory only; it is
/// null for entries rebuilt from upload history, because files are never
/// stored.
class PickedSyllabus {
  const PickedSyllabus({
    required this.name,
    required this.sizeBytes,
    this.bytes,
  });

  final String name;
  final int sizeBytes;
  final Uint8List? bytes;
}

/// Everything collected on the upload screen. [hint] carries the user's
/// note when they ask for a re-extraction ("you missed the final exam").
class SyllabusUpload {
  const SyllabusUpload({
    required this.file,
    required this.semesterStart,
    required this.timeZone,
    this.hint,
  });

  final PickedSyllabus file;
  final DateTime semesterStart;
  final String timeZone;
  final String? hint;

  SyllabusUpload copyWith({String? hint}) => SyllabusUpload(
        file: file,
        semesterStart: semesterStart,
        timeZone: timeZone,
        hint: hint ?? this.hint,
      );
}

enum EventType { exam, assignment, reading, project }

/// v0 shape of an extracted item. Optional fields stay optional so the
/// schema can change without touching every screen.
class ExtractedEvent {
  const ExtractedEvent({
    required this.id,
    required this.title,
    required this.type,
    required this.date,
    required this.course,
    this.time,
    this.confidence,
    this.sourceQuote,
  });

  final String id;
  final String title;
  final EventType type;
  final DateTime date;
  final String course;
  final String? time;
  final double? confidence; // 0..1
  final String? sourceQuote;

  /// Low-confidence items get a "Check this" flag on the review screen.
  bool get needsReview => (confidence ?? 1) < 0.75;

  /// Edits clear the confidence flag, since a person has now looked at it.
  ExtractedEvent copyWith({
    String? title,
    EventType? type,
    DateTime? date,
    String? course,
    String? time,
    bool clearTime = false,
  }) =>
      ExtractedEvent(
        id: id,
        title: title ?? this.title,
        type: type ?? this.type,
        date: date ?? this.date,
        course: course ?? this.course,
        time: clearTime ? null : (time ?? this.time),
        confidence: 1,
        sourceQuote: sourceQuote,
      );
}

/// Where the confirmed dates get saved.
enum SaveDestination { device, google, microsoft }
