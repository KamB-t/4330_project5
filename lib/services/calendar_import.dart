import '../models/syllabus.dart';

/// The page where [destination] imports a calendar file, or null for the
/// device calendar, which opens the downloaded file directly.
///
/// Importing a file needs no sign-in from the app and no API setup: the
/// user is already signed in to their calendar in the browser.
String? importPageUrl(SaveDestination destination) => switch (destination) {
  SaveDestination.device => null,
  // Settings > Import & export.
  SaveDestination.google =>
    'https://calendar.google.com/calendar/r/settings/export',
  // Add calendar > Upload from file (school and work accounts land here;
  // Outlook.com accounts are redirected to their own calendar).
  SaveDestination.microsoft => 'https://outlook.office.com/calendar/addcalendar',
};

/// What the user does with [fileName] once it has downloaded.
String importSteps(SaveDestination destination, String fileName) =>
    switch (destination) {
      SaveDestination.device =>
        'Open $fileName to add the dates to your calendar app.',
      SaveDestination.google =>
        'In the Google Calendar tab, under Import, choose $fileName '
            'and click Import.',
      SaveDestination.microsoft =>
        'In the Outlook tab, choose Add calendar > Upload from file, pick '
            '$fileName and click Import.',
    };
