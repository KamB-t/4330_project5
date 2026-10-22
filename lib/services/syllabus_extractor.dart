import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

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

/// Sends a syllabus to the LLM and reports progress. Implementations call
/// our own backend (never ship the LLM API key in the app). Failures are
/// thrown as stream errors, and cancelling the stream subscription cancels
/// the request.
/// When [SyllabusUpload.hint] is set this is a re-extraction: pass the
/// hint to the model so it can fix what the user said was wrong.
abstract interface class SyllabusExtractor {
  Stream<ExtractionUpdate> extract(SyllabusUpload upload);
}

/// A failure with a message that is safe to show the user.
class ExtractionException implements Exception {
  const ExtractionException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Supplies the signed-in user's Firebase ID token (null if signed out).
typedef IdTokenProvider = Future<String?> Function();

const _ianaZones = {
  'Eastern (ET)': 'America/New_York',
  'Central (CT)': 'America/Chicago',
  'Mountain (MT)': 'America/Denver',
  'Pacific (PT)': 'America/Los_Angeles',
  'Alaska (AKT)': 'America/Anchorage',
  'Hawaii (HT)': 'Pacific/Honolulu',
};

/// Calls the Cloudflare Worker proxy, which holds the Gemini key.
///
/// The Worker answers with newline-delimited JSON as it works, and each
/// stage here is emitted when the Worker reports it:
///  - uploading: from the start until the Worker has received the whole file
///  - reading:   the file is validated and Gemini is processing the document
///  - finding:   Gemini has started producing dates
///  - checking:  the Worker is validating the output
/// For the stages to appear live, [clientFactory] must return a client that
/// streams response bodies (see [streamingClient]).
class ProxySyllabusExtractor implements SyllabusExtractor {
  ProxySyllabusExtractor({
    required this.endpoint,
    required this.idToken,
    http.Client Function()? clientFactory,
    this.idleTimeout = const Duration(seconds: 90),
  }) : _clientFactory = clientFactory ?? http.Client.new;

  final Uri endpoint;
  final IdTokenProvider idToken;

  /// Longest we wait for the next message from the Worker.
  final Duration idleTimeout;
  final http.Client Function() _clientFactory;

  @override
  Stream<ExtractionUpdate> extract(SyllabusUpload upload) {
    final client = _clientFactory();
    final controller = StreamController<ExtractionUpdate>();
    var cancelled = false;

    void emit(ExtractionUpdate update) {
      if (!cancelled && !controller.isClosed) controller.add(update);
    }

    Future<void> run() async {
      try {
        emit(const StageReached(ExtractionStage.uploading));

        final bytes = upload.file.bytes;
        if (bytes == null) {
          throw const ExtractionException(
            'The file is no longer available. Please choose it again.',
          );
        }
        final token = await idToken();
        if (token == null) {
          throw const ExtractionException('Please sign in and try again.');
        }

        final request = http.Request('POST', endpoint)
          ..headers['Content-Type'] = 'application/json'
          ..headers['Authorization'] = 'Bearer $token'
          ..body = jsonEncode({
            'fileBase64': base64Encode(bytes),
            'mimeType': 'application/pdf',
            'semesterStart': _isoDate(upload.semesterStart),
            'timeZone': _ianaZones[upload.timeZone] ?? upload.timeZone,
            if (upload.hint != null && upload.hint!.trim().isNotEmpty)
              'hint': upload.hint!.trim(),
          });

        // Headers arrive only after the Worker has the whole upload and has
        // accepted it, so a response here means "uploading" is finished.
        final response = await client.send(request).timeout(idleTimeout);
        if (cancelled) return;
        if (response.statusCode != 200) {
          final full = await http.Response.fromStream(response);
          throw ExtractionException(
            _errorMessage(full),
            statusCode: response.statusCode,
          );
        }

        final lines = response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .timeout(idleTimeout);

        var finished = false;
        await for (final line in lines) {
          if (cancelled) return;
          if (line.trim().isEmpty) continue;
          final Object? message;
          try {
            message = jsonDecode(line);
          } catch (_) {
            throw const ExtractionException('Got an unreadable response.');
          }
          if (message is! Map) continue;

          final stage = message['stage'];
          if (stage is String) {
            final known = ExtractionStage.values.asNameMap()[stage];
            if (known != null) emit(StageReached(known));
          } else if (message['error'] is String) {
            throw ExtractionException(message['error'] as String);
          } else if (message['result'] is Map) {
            emit(ExtractionComplete(_parseEvents(message['result'] as Map)));
            finished = true;
          }
        }
        if (!finished && !cancelled) {
          throw const ExtractionException(
            'The connection closed before results arrived. Please try again.',
          );
        }
      } on TimeoutException {
        _fail(controller, cancelled,
            const ExtractionException('The request took too long. Try again.'));
      } on http.ClientException {
        _fail(controller, cancelled,
            const ExtractionException('Could not reach the extraction service.'));
      } catch (e, st) {
        if (!cancelled && !controller.isClosed) controller.addError(e, st);
      } finally {
        client.close();
        if (!controller.isClosed) unawaited(controller.close());
      }
    }

    controller.onListen = () => unawaited(run());
    controller.onCancel = () {
      cancelled = true;
      client.close(); // aborts the in-flight request
    };
    return controller.stream;
  }

  static void _fail(
    StreamController<ExtractionUpdate> controller,
    bool cancelled,
    ExtractionException error,
  ) {
    if (!cancelled && !controller.isClosed) controller.addError(error);
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String _errorMessage(http.Response response) {
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final message = body is Map ? body['error'] : null;
      if (message is String && message.isNotEmpty) return message;
    } catch (_) {}
    return switch (response.statusCode) {
      401 => 'Your sign-in expired. Please sign in again.',
      413 => 'That file is too large.',
      429 => 'Too many requests. Please wait a bit and try again.',
      _ => 'Extraction failed. Please try again.',
    };
  }

  static List<ExtractedEvent> _parseEvents(Map result) {
    final list = result['events'];
    if (list is! List) {
      throw const ExtractionException('Got an unreadable response.');
    }

    final events = <ExtractedEvent>[];
    for (final item in list) {
      if (item is! Map) continue;
      final date = DateTime.tryParse('${item['date']}');
      final title = item['title'];
      if (date == null || title is! String || title.isEmpty) continue;
      final time = item['time'];
      final confidence = item['confidence'];
      final quote = item['sourceQuote'];
      events.add(
        ExtractedEvent(
          id: '${events.length + 1}',
          title: title,
          type: EventType.values.asNameMap()['${item['type']}'] ??
              EventType.assignment,
          date: date,
          course: '${item['course'] ?? ''}',
          time: time is String && time.isNotEmpty ? time : null,
          confidence: confidence is num ? confidence.toDouble() : null,
          sourceQuote: quote is String && quote.isNotEmpty ? quote : null,
        ),
      );
    }
    return events;
  }
}
