import 'package:app5/models/syllabus.dart';
import 'package:app5/services/ics_builder.dart';
import 'package:flutter_test/flutter_test.dart';

String _ics(String time, {EventType type = EventType.exam}) =>
    IcsBuilder.build(
      [
        ExtractedEvent(
          id: '1',
          title: 'Lab',
          type: type,
          date: DateTime(2026, 10, 13),
          course: 'BIO 2310',
          time: time,
        ),
      ],
      timeZoneLabel: 'Central (CT)',
      now: DateTime.utc(2026, 9, 1),
    );

void main() {
  group('parseClockRange', () {
    test('reads both ends of a range', () {
      expect(parseClockRange('9:30-10:45 AM'), (
        start: (hour: 9, minute: 30),
        end: (hour: 10, minute: 45),
      ));
      expect(parseClockRange('6 PM to 8 PM'), (
        start: (hour: 18, minute: 0),
        end: (hour: 20, minute: 0),
      ));
      expect(parseClockRange('14:00 - 15:30'), (
        start: (hour: 14, minute: 0),
        end: (hour: 15, minute: 30),
      ));
    });

    test('the start borrows AM/PM from the end', () {
      expect(parseClockRange('2 – 3:15 pm')?.start, (hour: 14, minute: 0));
      expect(parseClockRange('11-12:15 PM')?.start, (hour: 11, minute: 0));
      expect(parseClockTime('2-3:15 PM'), (hour: 14, minute: 0));
    });

    test('drops an end that is missing or not after the start', () {
      expect(parseClockRange('2:00 PM')?.end, isNull);
      expect(parseClockRange('3:00 PM - 1:00 PM')?.end, isNull);
      expect(parseClockRange('2 PM - TBA'), (
        start: (hour: 14, minute: 0),
        end: null,
      ));
    });

    test('returns null when the start cannot be read', () {
      expect(parseClockRange(null), isNull);
      expect(parseClockRange('TBA - 3 PM'), isNull);
    });
  });

  group('.ics end times', () {
    test('a range sets the end time', () {
      final ics = _ics('9:30-10:45 AM');
      expect(ics, contains('DTSTART;TZID=America/Chicago:20261013T093000'));
      expect(ics, contains('DTEND;TZID=America/Chicago:20261013T104500'));
    });

    test('without a range the default length still applies', () {
      expect(_ics('2:00 PM'), contains('DTEND;TZID=America/Chicago:20261013T150000'));
      expect(
        _ics('2:00 PM', type: EventType.assignment),
        contains('DTEND;TZID=America/Chicago:20261013T143000'),
      );
    });
  });
}
