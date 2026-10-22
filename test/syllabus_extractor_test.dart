import 'dart:convert';
import 'dart:typed_data';

import 'package:app5/models/syllabus.dart';
import 'package:app5/services/syllabus_extractor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

SyllabusUpload _upload({Uint8List? bytes, String? hint}) => SyllabusUpload(
  file: PickedSyllabus(name: 'a.pdf', sizeBytes: 5, bytes: bytes),
  semesterStart: DateTime(2026, 8, 24),
  timeZone: 'Central (CT)',
  hint: hint,
);

final _pdf = Uint8List.fromList('%PDF-'.codeUnits);

http.Response _stream(List<Map<String, Object?>> messages, [int status = 200]) =>
    http.Response('${messages.map(jsonEncode).join('\n')}\n', status);

ProxySyllabusExtractor _extractor(
  Future<http.Response> Function(http.Request) handler, {
  String? token = 'token-123',
}) => ProxySyllabusExtractor(
  endpoint: Uri.parse('http://localhost:8787'),
  idToken: () async => token,
  clientFactory: () => MockClient(handler),
);

void main() {
  test('sends the file, date, zone and token, then parses events', () async {
    late http.Request seen;
    final extractor = _extractor((request) async {
      seen = request;
      return _stream([
        {'stage': 'reading'},
        {'stage': 'finding'},
        {'stage': 'checking'},
        {
          'result': {
            'events': [
              {
                'title': 'Midterm',
                'type': 'exam',
                'date': '2026-10-13',
                'time': '2:00 PM',
                'course': 'BIO 2310',
                'confidence': 0.9,
                'sourceQuote': 'Midterm: Oct 13',
              },
              {'title': 'Broken', 'date': 'not-a-date'},
            ],
          },
        },
      ]);
    });

    final updates = await extractor
        .extract(_upload(bytes: _pdf, hint: 'missed the final'))
        .toList();

    expect(seen.headers['Authorization'], 'Bearer token-123');
    final body = jsonDecode(seen.body) as Map<String, dynamic>;
    expect(body['semesterStart'], '2026-08-24');
    expect(body['timeZone'], 'America/Chicago');
    expect(body['mimeType'], 'application/pdf');
    expect(body['hint'], 'missed the final');
    expect(base64Decode(body['fileBase64'] as String), _pdf);

    // Stages come from the Worker, in order.
    expect(
      updates.whereType<StageReached>().map((u) => u.stage),
      [
        ExtractionStage.uploading,
        ExtractionStage.reading,
        ExtractionStage.finding,
        ExtractionStage.checking,
      ],
    );
    final done = updates.last as ExtractionComplete;
    expect(done.events, hasLength(1)); // the malformed one is dropped
    expect(done.events.single.title, 'Midterm');
    expect(done.events.single.type, EventType.exam);
    expect(done.events.single.date, DateTime(2026, 10, 13));
    expect(done.events.single.time, '2:00 PM');
    expect(done.events.single.confidence, 0.9);
  });

  test('surfaces the server error message', () async {
    final extractor = _extractor(
      (_) async => http.Response(jsonEncode({'error': 'Busy, try again'}), 429),
    );
    expect(
      extractor.extract(_upload(bytes: _pdf)).toList(),
      throwsA(
        isA<ExtractionException>()
            .having((e) => e.message, 'message', 'Busy, try again')
            .having((e) => e.statusCode, 'statusCode', 429),
      ),
    );
  });

  test('fails without calling the server when the file bytes are gone', () async {
    var called = false;
    final extractor = _extractor((_) async {
      called = true;
      return http.Response('{}', 200);
    });
    await expectLater(
      extractor.extract(_upload()).toList(),
      throwsA(isA<ExtractionException>()),
    );
    expect(called, isFalse);
  });

  test('fails without calling the server when signed out', () async {
    var called = false;
    final extractor = _extractor((_) async {
      called = true;
      return http.Response('{}', 200);
    }, token: null);
    await expectLater(
      extractor.extract(_upload(bytes: _pdf)).toList(),
      throwsA(isA<ExtractionException>()),
    );
    expect(called, isFalse);
  });

  test('an unreadable response is an error, not an empty result', () async {
    final extractor = _extractor((_) async => http.Response('oops', 200));
    await expectLater(
      extractor.extract(_upload(bytes: _pdf)).toList(),
      throwsA(isA<ExtractionException>()),
    );
  });

  test('an error sent mid-stream becomes an ExtractionException', () async {
    final extractor = _extractor(
      (_) async => _stream([
        {'stage': 'reading'},
        {'error': 'Extraction failed'},
      ]),
    );
    await expectLater(
      extractor.extract(_upload(bytes: _pdf)).toList(),
      throwsA(
        isA<ExtractionException>().having(
          (e) => e.message,
          'message',
          'Extraction failed',
        ),
      ),
    );
  });

  test('a stream that ends without a result is an error', () async {
    final extractor = _extractor(
      (_) async => _stream([
        {'stage': 'reading'},
        {'stage': 'finding'},
      ]),
    );
    await expectLater(
      extractor.extract(_upload(bytes: _pdf)).toList(),
      throwsA(isA<ExtractionException>()),
    );
  });
}
