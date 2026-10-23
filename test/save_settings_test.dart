import 'package:app5/models/syllabus.dart';
import 'package:app5/screens/destination_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('starts on the device calendar', () {
    expect(SaveSettings().destination, SaveDestination.device);
  });

  test('selecting a new destination notifies once', () {
    final settings = SaveSettings();
    var notified = 0;
    settings.addListener(() => notified++);

    settings.select(SaveDestination.google);
    settings.select(SaveDestination.google);

    expect(settings.destination, SaveDestination.google);
    expect(notified, 1);
  });

  test('every destination has a name and icon', () {
    for (final d in SaveDestination.values) {
      expect(saveDestinationName(d), isNotEmpty);
      expect(saveDestinationIcon(d), isNotNull);
    }
  });
}
