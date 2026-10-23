# Syllabus to Calendar

Turn a syllabus into calendar events in a few taps.

Syllabus to Calendar reads the dates out of a course syllabus (exams, assignments, deadlines) and gives you a calendar file you can add to any calendar app.

## How it works

1. **Upload** your syllabus (up to 5 MB), then choose the semester start date and your time zone.
2. **Extract**: the file is sent to our backend, a Cloudflare Worker that holds the Gemini API key, and the extracted events stream back as it works.
3. **Review** the events. If something is wrong, add a note such as "you missed the final exam" and re-extract.
4. **Save** the events as an `.ics` file, with real times where the syllabus
   gives them (including ranges like "9:30-10:45 AM" and deadlines like
   "by 11:59 pm"). Pick where they go:
   - **Phone calendar:** opens in your calendar app (downloads on the web).
   - **Google Calendar:** on the web, the file downloads and Google
     Calendar's import page opens. Choose the file and click Import.
   - **Outlook:** on the web, the file downloads and Outlook's Add calendar
     page opens. Choose Upload from file.

   No calendar sign-in or setup is needed.

The Account tab supports Google sign-in. Each upload's metadata is saved to your history. Syllabus files and extracted events are not stored.

## Tech

- Flutter (Android, iOS, web)
- Firebase Auth and Firestore for accounts and upload history
- Cloudflare Worker proxy calling Gemini for extraction
- `.ics` export

## Run

```sh
flutter pub get
flutter run -d chrome --web-port 5174
```

See [FIREBASE_SETUP.md](FIREBASE_SETUP.md) for Firebase configuration, including the one-time Android setup.

## Test

```sh
flutter test
flutter analyze
```

CI runs the tests, the analyzer and a web build on every push.

## Project layout

- `lib/screens/`: upload, processing, review, destination, history and account screens
- `lib/services/`: extraction client, `.ics` builder and delivery, calendar import pages, upload history, account session
- `lib/models/`: syllabus and extracted-event models
- `lib/theme/` and `lib/widgets/`: shared styling and UI components
