import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Public Firebase client configuration. Access is controlled by Auth and rules.
const firebaseWebOptions = FirebaseOptions(
  apiKey: 'AIzaSyDgh6bkRBDbPi_YyRSVpuO8iw2rCGK-rRM',
  appId: '1:253879204438:web:f872d29d9d8c42f7da99f7',
  messagingSenderId: '253879204438',
  projectId: 'proj5swsys',
  authDomain: 'proj5swsys.firebaseapp.com',
  storageBucket: 'proj5swsys.firebasestorage.app',
);

/// Android app registered in the Firebase console (package com.example.app5).
/// Leave the REPLACE values until it is registered. Then copy `apiKey` (current_key) and `appId` (mobilesdk_app_id) from the
/// downloaded google-services.json. See FIREBASE_SETUP.md.
const firebaseAndroidOptions = FirebaseOptions(
  apiKey: 'REPLACE_WITH_ANDROID_API_KEY',
  appId: 'REPLACE_WITH_ANDROID_APP_ID',
  messagingSenderId: '253879204438',
  projectId: 'proj5swsys',
  storageBucket: 'proj5swsys.firebasestorage.app',
);

FirebaseOptions currentFirebaseOptions() {
  if (kIsWeb) return firebaseWebOptions;
  if (defaultTargetPlatform == TargetPlatform.android) {
    final registered =
        !firebaseAndroidOptions.apiKey.startsWith('REPLACE') &&
        !firebaseAndroidOptions.appId.startsWith('REPLACE');
    // Until an Android app is registered, reuse the web settings so the app can
    // run as a guest. Google sign-in needs the real Android registration.
    return registered ? firebaseAndroidOptions : firebaseWebOptions;
  }
  throw UnsupportedError('Firebase is configured for web and Android only.');
}
