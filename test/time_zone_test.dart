import 'package:app5/models/syllabus.dart';
import 'package:app5/services/ics_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('labels and IANA names are unique', () {
    final labels = timeZoneOptions.map((z) => z.label).toSet();
    final names = timeZoneOptions.map((z) => z.iana).toSet();
    expect(labels, hasLength(timeZoneOptions.length));
    expect(names, hasLength(timeZoneOptions.length));
  });

  test('looks zones up by label', () {
    expect(timeZoneByLabel('Central (CT)')?.iana, 'America/Chicago');
    expect(timeZoneByLabel('Mars (MT)'), isNull);
  });

  test('every offered zone has .ics rules under the same IANA name', () {
    for (final zone in timeZoneOptions) {
      final ics = IcsBuilder.build(
        [
          ExtractedEvent(
            id: '1',
            title: 'Midterm',
            type: EventType.exam,
            date: DateTime(2026, 10, 13),
            course: 'BIO 2310',
            time: '2:00 PM',
          ),
        ],
        timeZoneLabel: zone.label,
        now: DateTime.utc(2026, 9, 1),
      );
      expect(ics, contains('TZID:${zone.iana}\r\n'), reason: zone.label);
      expect(
        ics,
        contains('DTSTART;TZID=${zone.iana}:20261013T140000'),
        reason: zone.label,
      );
    }
  });
}
