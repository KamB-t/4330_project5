import 'dart:convert';

import 'package:app5/models/syllabus.dart';
import 'package:app5/services/google_calendar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

ExtractedEvent event({String id = '1', String? time, DateTime? date}) =>
    ExtractedEvent(
      id: id,
      title: 'Final exam',
      type: EventType.exam,
      date: date ?? DateTime(2026, 12, 15),
      course: 'CSC 4330',
      time: time,
    );

void main() {
  test('all-day end is exclusive, including year rollover', () {
    final body = googleEvent(
      event(date: DateTime(2026, 12, 31)),
      'Central (CT)',
    );
    expect(body['start'], {'date': '2026-12-31'});
    expect(body['end'], {'date': '2027-01-01'});
    expect(body['summary'], 'CSC 4330: Final exam');
  });

  test('timed events retain local wall time and IANA zone across midnight', () {
    final body = googleEvent(event(time: '11:30 PM'), 'Central (CT)');
    expect(body['start'], {
      'dateTime': '2026-12-15T23:30:00.000',
      'timeZone': 'America/Chicago',
    });
    expect(body['end'], {
      'dateTime': '2026-12-16T00:30:00.000',
      'timeZone': 'America/Chicago',
    });
  });

  test('stable event IDs survive extraction ID changes', () {
    final first = googleEvent(event(), 'Central (CT)')['id'];
    expect(googleEvent(event(id: 'new-id'), 'Central (CT)')['id'], first);
    expect(
      googleEvent(event(time: '2 PM'), 'Central (CT)')['id'],
      isNot(first),
    );
  });

  test(
    'partial failures report progress; retry reuses IDs and accepts duplicates',
    () async {
      var calls = 0;
      final ids = <Object?>[];
      final calendar = GoogleCalendar(
        authorize: () async => 'google-access-token',
        client: MockClient((request) async {
          expect(request.url.path, '/calendar/v3/calendars/primary/events');
          expect(
            request.headers['authorization'],
            'Bearer google-access-token',
          );
          ids.add((jsonDecode(request.body) as Map)['id']);
          calls++;
          return http.Response('{}', switch (calls) {
            2 => 503,
            3 => 409,
            _ => 200,
          });
        }),
      );
      addTearDown(calendar.dispose);
      final events = [event(), event(time: 'noon')];
      await expectLater(
        calendar.save(events, 'Central (CT)'),
        throwsA(
          isA<CalendarSaveException>().having((e) => e.saved, 'saved', 1),
        ),
      );
      expect(await calendar.save(events, 'Central (CT)'), 2);
      expect(ids[0], ids[2]);
      expect(ids[1], ids[3]);
    },
  );

  test('401 clears access token and next save reconnects', () async {
    var grants = 0;
    final calendar = GoogleCalendar(
      authorize: () async => 'token-${++grants}',
      client: MockClient(
        (request) async => http.Response('{}', grants == 1 ? 401 : 200),
      ),
    );
    addTearDown(calendar.dispose);
    await expectLater(
      calendar.save([event()], 'Central (CT)'),
      throwsA(isA<CalendarSaveException>()),
    );
    expect(await calendar.save([event()], 'Central (CT)'), 1);
    expect(grants, 2);
  });

  test('permission denial does not claim success', () async {
    final calendar = GoogleCalendar(
      authorize: () async => 'token',
      client: MockClient((_) async => http.Response('{}', 403)),
    );
    addTearDown(calendar.dispose);
    await expectLater(
      calendar.save([event()], 'Central (CT)'),
      throwsA(
        isA<CalendarSaveException>()
            .having((e) => e.saved, 'saved', 0)
            .having((e) => e.message, 'message', contains('permission')),
      ),
    );
  });

  test(
    'invalid timed zone is rejected before authorization or writes',
    () async {
      var authorized = false;
      final calendar = GoogleCalendar(
        authorize: () async {
          authorized = true;
          return 'token';
        },
      );
      addTearDown(calendar.dispose);
      await expectLater(
        calendar.save([event(time: 'noon')], 'unknown'),
        throwsA(isA<CalendarSaveException>()),
      );
      expect(authorized, false);
    },
  );
}
