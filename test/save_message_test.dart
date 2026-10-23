import 'package:app5/main.dart';
import 'package:app5/models/syllabus.dart';
import 'package:app5/services/ics_delivery.dart';
import 'package:flutter_test/flutter_test.dart';

String _message(
  IcsDeliveryResult result, {
  SaveDestination destination = SaveDestination.device,
  int count = 3,
  bool openedImportPage = false,
}) => saveMessage(
  result: result,
  destination: destination,
  fileName: 'BIO_dates.ics',
  count: count,
  openedImportPage: openedImportPage,
);

void main() {
  test('a phone calendar app opened the file', () {
    expect(
      _message(IcsDeliveryResult.opened, count: 1),
      'Opened 1 date in your calendar app. Confirm there to add them.',
    );
  });

  test('a plain download says to open the file', () {
    expect(
      _message(IcsDeliveryResult.downloaded),
      'Downloaded BIO_dates.ics with 3 dates. Open it to add them to your '
      'calendar.',
    );
  });

  test('Google Calendar explains the import step', () {
    final message = _message(
      IcsDeliveryResult.downloaded,
      destination: SaveDestination.google,
      openedImportPage: true,
    );
    expect(message, startsWith('Downloaded BIO_dates.ics with 3 dates. '));
    expect(message, contains('Google Calendar tab'));
    expect(message, contains('Import'));
  });

  test('Outlook explains the upload step', () {
    expect(
      _message(
        IcsDeliveryResult.downloaded,
        destination: SaveDestination.microsoft,
        openedImportPage: true,
      ),
      contains('Upload from file'),
    );
  });

  test('failures keep their own messages', () {
    expect(
      _message(IcsDeliveryResult.noApp),
      'No calendar app found on this device to open the file.',
    );
    expect(
      _message(IcsDeliveryResult.failed, destination: SaveDestination.google),
      'Could not create the calendar file. Please try again.',
    );
  });
}
