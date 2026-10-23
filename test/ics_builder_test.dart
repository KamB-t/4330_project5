import 'dart:convert';

import 'package:app5/models/syllabus.dart';
import 'package:app5/services/ics_builder.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 10, 23, 12, 0, 0);

ExtractedEvent _event({
  String id = '1',
  String title = 'Midterm exam',
  EventType type = EventType.exam,
  DateTime? date,
  String course = 'BIO 2310',
  String? time = '2:00 PM',
  String? quote,
}) => ExtractedEvent(
  id: id,
  title: title,
  type: type,
  date: date ?? DateTime(2026, 10, 13),
  course: course,
  time: time,
  sourceQuote: quote,
);

String _build(List<ExtractedEvent> events, {String zone = 'Central (CT)'}) =>
    IcsBuilder.build(events, timeZoneLabel: zone, now: _now);

/// Lines of the file with folded continuations joined back together.
List<String> _unfolded(String ics) =>
    ics.replaceAll('\r\n ', '').split('\r\n')..removeLast();

void main() {
  group('parseClockTime', () {
    test('reads common formats', () {
      expect(parseClockTime('2:00 PM'), (hour: 14, minute: 0));
      expect(parseClockTime('11:59pm'), (hour: 23, minute: 59));
      expect(parseClockTime('2 p.m.'), (hour: 14, minute: 0));
      expect(parseClockTime('12:00 AM'), (hour: 0, minute: 0));
      expect(parseClockTime('12:30 PM'), (hour: 12, minute: 30));
      expect(parseClockTime('14:30'), (hour: 14, minute: 30));
      expect(parseClockTime('Noon'), (hour: 12, minute: 0));
    });

    test('uses the start of a range', () {
      expect(parseClockTime('2:00 PM - 3:15 PM'), (hour: 14, minute: 0));
    });

    test('returns null when it cannot be read', () {
      expect(parseClockTime(null), isNull);
      expect(parseClockTime(''), isNull);
      expect(parseClockTime('after class'), isNull);
      expect(parseClockTime('13:00 PM'), isNull);
      expect(parseClockTime('9:75 AM'), isNull);
    });
  });

  group('IcsBuilder', () {
    test('has the calendar wrapper and Windows line endings', () {
      final ics = _build([_event()]);
      expect(ics, startsWith('BEGIN:VCALENDAR\r\nVERSION:2.0\r\n'));
      expect(ics, endsWith('END:VCALENDAR\r\n'));
      expect(ics.replaceAll('\r\n', ''), isNot(contains('\n')));
    });

    test('timed event carries the time zone and a one-hour exam', () {
      final lines = _unfolded(_build([_event()]));
      expect(lines, contains('DTSTART;TZID=America/Chicago:20261013T140000'));
      expect(lines, contains('DTEND;TZID=America/Chicago:20261013T150000'));
      expect(lines, contains('SUMMARY:BIO 2310: Midterm exam'));
      expect(lines, contains('CATEGORIES:Exam'));
      expect(lines, isNot(contains('TRANSP:TRANSPARENT')));
    });

    test('due dates are 30 minutes and may cross midnight', () {
      final lines = _unfolded(
        _build([
          _event(
            type: EventType.assignment,
            time: '11:45 PM',
            date: DateTime(2026, 10, 15),
          ),
        ]),
      );
      expect(lines, contains('DTSTART;TZID=America/Chicago:20261015T234500'));
      expect(lines, contains('DTEND;TZID=America/Chicago:20261016T001500'));
    });

    test('no time means an all-day event that ends the next day', () {
      final lines = _unfolded(
        _build([_event(time: null, date: DateTime(2026, 10, 31))]),
      );
      expect(lines, contains('DTSTART;VALUE=DATE:20261031'));
      expect(lines, contains('DTEND;VALUE=DATE:20261101'));
      expect(lines, contains('TRANSP:TRANSPARENT'));
    });

    test('all-day across a month and year end', () {
      final lines = _unfolded(
        _build([_event(time: null, date: DateTime(2026, 12, 31))]),
      );
      expect(lines, contains('DTEND;VALUE=DATE:20270101'));
    });

    test('an unreadable time becomes all-day and is kept in the notes', () {
      final lines = _unfolded(_build([_event(time: 'after class')]));
      expect(lines.any((l) => l.startsWith('DTSTART;VALUE=DATE:')), isTrue);
      expect(
        lines.any((l) => l.startsWith('DESCRIPTION:') && l.contains('after class')),
        isTrue,
      );
    });

    test('includes the time zone rules once, only when a timed event exists', () {
      final timed = _build([_event(), _event(id: '2', title: 'Quiz')]);
      expect('BEGIN:VTIMEZONE'.allMatches(timed), hasLength(1));
      expect(timed, contains('RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=2SU'));
      expect(timed, contains('RRULE:FREQ=YEARLY;BYMONTH=11;BYDAY=1SU'));
      expect(timed, contains('TZOFFSETTO:-0500')); // CDT

      final allDay = _build([_event(time: null)]);
      expect(allDay, isNot(contains('VTIMEZONE')));
    });

    test('each offered time zone has rules; Hawaii has no daylight saving', () {
      const expected = {
        'Eastern (ET)': 'America/New_York',
        'Central (CT)': 'America/Chicago',
        'Mountain (MT)': 'America/Denver',
        'Pacific (PT)': 'America/Los_Angeles',
        'Alaska (AKT)': 'America/Anchorage',
        'Hawaii (HT)': 'Pacific/Honolulu',
      };
      expected.forEach((label, tzid) {
        final ics = _build([_event()], zone: label);
        expect(ics, contains('TZID:$tzid'));
        expect(ics, contains('DTSTART;TZID=$tzid:'));
      });
      expect(_build([_event()], zone: 'Hawaii (HT)'), isNot(contains('DAYLIGHT')));
    });

    test('an unknown zone label falls back to floating local time', () {
      final lines = _unfolded(_build([_event()], zone: 'Mars (MT)'));
      expect(lines, contains('DTSTART:20261013T140000'));
      expect(lines.join(), isNot(contains('VTIMEZONE')));
    });

    test('escapes commas, semicolons, backslashes and new lines', () {
      final lines = _unfolded(
        _build([_event(title: r'Lab; Part 1, 2 \ final', quote: 'line one\nline two')]),
      );
      expect(lines, contains(r'SUMMARY:BIO 2310: Lab\; Part 1\, 2 \\ final'));
      expect(
        lines.firstWhere((l) => l.startsWith('DESCRIPTION:')),
        contains(r'line one\nline two'),
      );
    });

    test('no course leaves the title alone', () {
      final lines = _unfolded(_build([_event(course: '')]));
      expect(lines, contains('SUMMARY:Midterm exam'));
    });

    test('folds long lines at 75 bytes without splitting a character', () {
      final ics = _build([
        _event(title: 'Étude de cas — ${'très long ' * 20}fin 😀'),
      ]);
      for (final line in ics.split('\r\n')) {
        expect(utf8.encode(line).length, lessThanOrEqualTo(75));
      }
      final title = _unfolded(ics).firstWhere((l) => l.startsWith('SUMMARY:'));
      expect(title, contains('Étude de cas — très long'));
      expect(title, endsWith('fin 😀'));
    });

    test('ids are stable between builds and unique within a file', () {
      String uidOf(List<ExtractedEvent> e) => _unfolded(_build(e))
          .where((l) => l.startsWith('UID:'))
          .join(',');

      expect(uidOf([_event()]), uidOf([_event()]));
      expect(uidOf([_event()]), isNot(uidOf([_event(title: 'Final exam')])));

      final twins = _unfolded(_build([_event(), _event(id: '2')]))
          .where((l) => l.startsWith('UID:'))
          .toList();
      expect(twins, hasLength(2));
      expect(twins.toSet(), hasLength(2));
      expect(twins.every((u) => u.endsWith('@syllabus-to-calendar')), isTrue);
    });

    test('every event has the required fields', () {
      final lines = _unfolded(_build([_event(), _event(id: '2', time: null)]));
      expect(lines.where((l) => l == 'BEGIN:VEVENT'), hasLength(2));
      expect(lines.where((l) => l == 'END:VEVENT'), hasLength(2));
      expect(lines.where((l) => l.startsWith('DTSTAMP:20261023T120000Z')), hasLength(2));
      expect(lines.where((l) => l.startsWith('UID:')), hasLength(2));
    });
  });
}
