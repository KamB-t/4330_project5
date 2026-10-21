/// A syllabus the user has selected. Map your file picker result to this.
class PickedSyllabus {
  const PickedSyllabus({required this.name, required this.sizeBytes});

  final String name;
  final int sizeBytes;
}

/// Everything collected on the upload screen.
class SyllabusUpload {
  const SyllabusUpload({
    required this.file,
    required this.semesterStart,
    required this.timeZone,
  });

  final PickedSyllabus file;
  final DateTime semesterStart;
  final String timeZone;
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
}
