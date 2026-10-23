# Firebase history

Project: `proj5swsys`. The registered Firebase app is **Syllabus to Calendar Web(Termwise)**.
The Flutter web target is configured. Android needs the one-time setup below.

## Run

```powershell
flutter pub get
flutter run -d chrome --web-port 5174
```

On Windows, Flutter may request Developer Mode to create plugin symlinks. Enable
it in Windows Settings if dependency installation reports this requirement.

## How it works

The app initializes Firebase and reuses the current Firebase Auth user, or signs
in anonymously. Each submission writes metadata under
`users/{uid}/uploads/{uploadId}`. A live Firestore query shows the latest 20
entries ordered by server upload time. Older records remain in Firestore.
No PDF contents or extracted events are stored by this integration.

The Account tab offers Google sign-in and sign-out. Linking a guest to a new
Google-backed Firebase account preserves its UID and existing history. Signing
in with that Google account on another device loads the same Firestore path.
If the Google account already belongs to another Firebase user, the app asks
before switching: it loads that account's history and does not migrate guest
uploads. Canceling keeps the guest account and its history accessible. Guest
history is never automatically deleted. Signing out creates a fresh guest and
clears the old account's routes and visible history.

Anonymous authentication preserves history for that browser profile and origin.
Keep the same localhost port when testing. Private browsing, clearing site data,
or using another device creates a different guest account. Link a permanent
account for cross-device access. Flutter's temporary Chrome profile
may also reset between debug sessions; use a persistent browser profile to test
restart persistence.

The file picker, AI extraction, account sign-in, calendar file export, and direct
Google Calendar saving are implemented. Outlook direct sync is not available.

## Direct Google Calendar saving

1. In the Google Cloud project linked to Firebase (`proj5swsys`), enable the
   **Google Calendar API** under APIs & Services > Library.
2. In Google Auth Platform > Data Access (OAuth consent screen), add
   `https://www.googleapis.com/auth/calendar.events.owned`. This allows event
   access on calendars owned by the user; Termwise writes to the primary calendar.
3. If the OAuth app is in Testing, add your Google account under Audience > Test
   users. Public external use may require Google's OAuth verification.
4. Keep Google sign-in enabled in Firebase Authentication and authorize your
   web domain (including localhost for development). Use the existing Firebase
   OAuth client and redirect URI; no client secret belongs in Flutter.

Sign in with Google on the Account tab **before uploading/extracting**. At review,
choose Change > Google Calendar > Connect, grant permission, then Use Google
Calendar. The Add dates button uploads all selected events directly, without an
ICS import. Nothing is sent to Calendar until that button is pressed.

Calendar authorization is separate from app sign-in and uses reauthentication
to keep the current account and review intact. Short-lived Google access tokens
stay in memory and are cleared on account changes; they are not stored in
Firestore. Expired or denied access asks for reconnection on the next save.
Dates without a readable time are all-day events. Timed events use the selected
time zone and default to one hour for exams or 30 minutes for other events,
matching the ICS export.

Content-derived Google event IDs prevent duplicate creation on retries, including
after a partial failure. Identical events are skipped; editing event content
creates a new event rather than changing a previously saved one. Saved events
are not removed if the user later deselects them in Termwise.

API reference: https://developers.google.com/workspace/calendar/api/v3/reference/events/insert

## AI extraction

The app never holds an AI key. It sends the PDF and the user's Firebase ID
token to a Cloudflare Worker, which verifies the token, calls Gemini with a
secret key, and streams back its real progress (upload received, Gemini
reading, dates found, checking) followed by the events. The app uses the deployed Worker by default, so running it from the IDE needs
no terminal flags. Chrome must be the selected device (the project has a
`.vscode/launch.json` that selects it). The Worker allows any `localhost` port.

To test a local Worker instead, run `npx wrangler dev` and start the app with
`--dart-define=EXTRACT_URL=http://localhost:8787`.
Syllabi are held in memory only;
upload history stores metadata, so "Extract again" asks you to re-select the file. The app reports history connection/write failures rather
than silently switching to session-only storage.

## Console configuration

- Enable Authentication > Sign-in method > Anonymous and Google. Google's
  public-facing project name is **Syllabus to Calendar**, with the project
  owner's email as the support contact.
- In Authentication > Settings > Authorized domains, include `localhost` and
  any hostnames where the web app actually runs. Use `localhost` for local
  testing; add `127.0.0.1` only if using that address.
- Create the default Cloud Firestore database in production mode.
- Publish the contents of `firestore.rules` under Firestore > Rules, or use
  `firebase deploy --only firestore:rules --project proj5swsys` after Firebase CLI login.
- Rules permit each signed-in user to read and create only their own upload
  metadata, validate its fields, and reject updates and deletes. Other paths are
  denied by default. These same rules cover Google users without modification.

Google app sign-in requests basic identity only. It does not enable calendar
writing; the existing calendar connection and save actions remain mocked.

The Firebase client configuration in `lib/firebase_options.dart` is public app
configuration, not a server credential. Never commit service-account keys or AI
provider secrets. Additional platforms should be registered and configured using
the official FlutterFire CLI before running them.

## Checks

```powershell
flutter test
flutter analyze
flutter build web
```

Widget tests inject in-memory history and do not contact the live project.

## Android

The app runs on an Android emulator or phone once the Android app is registered
in Firebase. This needs someone with the Editor or Owner role on `proj5swsys`
(or use your own Firebase project and replace the config).

1. Firebase console > Project settings > Your apps > Add app > Android.
   Package name: `com.example.app5`.
2. Add your debug SHA-1 (and SHA-256) fingerprint. Each developer's debug key
   is different, so add one per person:
   ```
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```
   On Windows the keystore is at `%USERPROFILE%\.android\debug.keystore`.
3. Download `google-services.json`. From it, copy `current_key` into
   `apiKey` and `mobilesdk_app_id` into `appId` in
   `firebaseAndroidOptions` in `lib/firebase_options.dart`. These are public
   client settings, not secrets. The `google-services.json` file itself is not
   needed in the project.
4. Use an emulator image that includes Google Play (it has Chrome), because
   Google sign-in opens in a browser tab.
5. In Android Studio, pick the emulator and run. The app uses the deployed
   Worker by default, which accepts Android requests (they send no `Origin`
   header and are protected by the Firebase sign-in check).

Until step 3 is done, the Android build reuses the web app's settings and runs
as a guest. Guest history and extraction work, but Google sign-in does not. If
that fallback is rejected by Firebase, register the app (steps above) or use a
separate Firebase project: enable Anonymous (and Google) sign-in, create a
Firestore database with `firestore.rules`, fill in the options, and give the
Worker the new project ID:
`npx wrangler secret put EXTRA_FIREBASE_PROJECT_IDS`.
