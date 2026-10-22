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
/// When [SyllabusUpload.hint] is set this is a re-extraction: pass the
/// hint to the model so it can fix what the user said was wrong.
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
        title: 'Lab report 1',
        type: EventType.assignment,
        date: start.add(const Duration(days: 18)),
        course: 'BIO 2310',
        confidence: 0.62,
        sourceQuote: 'Lab report 1 due the Friday of Week 3',
      ),
      ExtractedEvent(
        id: '2',
        title: 'Read chapters 4 and 5',
        type: EventType.reading,
        date: start.add(const Duration(days: 22)),
        course: 'BIO 2310',
        confidence: 0.91,
        sourceQuote: 'Week 4: Campbell Biology, ch. 4–5',
      ),
      ExtractedEvent(
        id: '3',
        title: 'Midterm exam',
        type: EventType.exam,
        date: start.add(const Duration(days: 49)),
        course: 'BIO 2310',
        time: '2:00 PM',
        confidence: 0.94,
        sourceQuote: 'Midterm: Week 8, Tuesday, 2:00 PM',
      ),
      ExtractedEvent(
        id: '4',
        title: 'Group project proposal',
        type: EventType.project,
        date: start.add(const Duration(days: 60)),
        course: 'BIO 2310',
        confidence: 0.55,
        sourceQuote: 'Proposal due before Thanksgiving break',
      ),
      ExtractedEvent(
        id: '5',
        title: 'Final exam',
        type: EventType.exam,
        date: start.add(const Duration(days: 105)),
        course: 'BIO 2310',
        time: '8:00 AM',
        confidence: 0.97,
        sourceQuote: 'Final exam: December 8, 8:00 AM',
      ),
    ]);
  }
}
