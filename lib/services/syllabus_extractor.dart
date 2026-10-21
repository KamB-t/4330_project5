import '../models/syllabus.dart';

enum ExtractionStage { uploading, reading, finding, checking }

sealed class ExtractionUpdate {
  const ExtractionUpdate();
}

class StageReached extends ExtractionUpdate {
  const StageReached(this.stage);
  final ExtractionStage stage;
}

class ExtractionComplete extends ExtractionUpdate {
  const ExtractionComplete(this.events);
  final List<ExtractedEvent> events;
}

/// Sends a syllabus to the LLM and reports progress. Everything happens
/// inside the app: the real version should call your own backend over
/// HTTPS (never ship the LLM API key in the app) and emit [StageReached]
/// as the request advances. Failures are thrown as stream errors, and
/// cancelling the stream subscription should cancel the request.
abstract interface class SyllabusExtractor {
  Stream<ExtractionUpdate> extract(SyllabusUpload upload);
}

/// Fake extractor for building the UI. Set [fail] to see the error state.
class MockSyllabusExtractor implements SyllabusExtractor {
  const MockSyllabusExtractor({this.fail = false});

  final bool fail;

  @override
  Stream<ExtractionUpdate> extract(SyllabusUpload upload) async* {
    for (final stage in ExtractionStage.values) {
      yield StageReached(stage);
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      if (fail && stage == ExtractionStage.finding) {
        throw Exception('Mock extraction failure');
      }
    }
    final start = upload.semesterStart;
    yield ExtractionComplete([
      ExtractedEvent(
        id: '1',
        title: 'Midterm exam',
        type: EventType.exam,
        date: start.add(const Duration(days: 49)),
        course: 'BIO 2310',
        time: '2:00 PM',
        confidence: 0.94,
        sourceQuote: 'Midterm: Week 8, Tuesday, 2:00 PM',
      ),
      ExtractedEvent(
        id: '2',
        title: 'Lab report 1',
        type: EventType.assignment,
        date: start.add(const Duration(days: 18)),
        course: 'BIO 2310',
        confidence: 0.62,
        sourceQuote: 'Lab report 1 due the Friday of Week 3',
      ),
    ]);
  }
}
