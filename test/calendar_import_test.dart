import 'package:app5/models/syllabus.dart';
import 'package:app5/services/calendar_import.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the device calendar has no import page', () {
    expect(importPageUrl(SaveDestination.device), isNull);
  });

  test('online calendars open their import page over https', () {
    for (final destination in [
      SaveDestination.google,
      SaveDestination.microsoft,
    ]) {
      final url = Uri.parse(importPageUrl(destination)!);
      expect(url.scheme, 'https');
    }
    expect(
      Uri.parse(importPageUrl(SaveDestination.google)!).host,
      'calendar.google.com',
    );
    expect(
      Uri.parse(importPageUrl(SaveDestination.microsoft)!).host,
      'outlook.office.com',
    );
  });

  test('steps name the downloaded file for every destination', () {
    for (final destination in SaveDestination.values) {
      expect(importSteps(destination, 'BIO-dates.ics'), contains('BIO-dates.ics'));
    }
    expect(
      importSteps(SaveDestination.google, 'a.ics'),
      contains('Google Calendar'),
    );
    expect(
      importSteps(SaveDestination.microsoft, 'a.ics'),
      contains('Upload from file'),
    );
  });
}
