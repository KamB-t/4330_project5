import 'package:app5/models/syllabus.dart';
import 'package:app5/services/ics_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('drops words in front of the time', () {
    expect(parseClockTime('by 11:59 pm'), (hour: 23, minute: 59));
    expect(parseClockTime('Due by 5 PM'), (hour: 17, minute: 0));
    expect(parseClockTime('at 9am'), (hour: 9, minute: 0));
    expect(parseClockTime('before  10:30 a.m.'), (hour: 10, minute: 30));
  });

  test('ignores a zone abbreviation after the time', () {
    expect(parseClockTime('2:00 PM CT'), (hour: 14, minute: 0));
    expect(parseClockTime('10 AM (EST)'), (hour: 10, minute: 0));
    expect(parseClockTime('11:59 pm CDT'), (hour: 23, minute: 59));
    expect(parseClockTime('9:00 AKST'), (hour: 9, minute: 0));
  });

  test('reads midnight as the end of the day', () {
    expect(parseClockTime('midnight'), (hour: 23, minute: 59));
    expect(parseClockTime('by Midnight'), (hour: 23, minute: 59));
  });

  test('still rejects text that is not a time', () {
    expect(parseClockTime('by the end of class'), isNull);
    expect(parseClockTime('due'), isNull);
    expect(parseClockTime('CT'), isNull);
  });

  test('a deadline with a filler word becomes a timed event', () {
    final ics = IcsBuilder.build(
      [
        ExtractedEvent(
          id: '1',
          title: 'Essay',
          type: EventType.assignment,
          date: DateTime(2026, 10, 15),
          course: 'ENGL 2000',
          time: 'by 11:59 PM CT',
        ),
      ],
      timeZoneLabel: 'Central (CT)',
      now: DateTime.utc(2026, 9, 1),
    );
    expect(ics, contains('DTSTART;TZID=America/Chicago:20261015T235900'));
  });
}
