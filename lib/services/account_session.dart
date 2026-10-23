import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AppAccount {
  const AppAccount({
    required this.id,
    required this.isGuest,
    this.name,
    this.email,
  });
  final String id;
  final bool isGuest;
  final String? name;
  final String? email;
}

class ExistingGoogleAccount implements Exception {
  const ExistingGoogleAccount();
}

abstract class AccountSession extends ChangeNotifier {
  AppAccount? get account;
  Future<void> signInGoogle();
  Future<void> useExistingGoogleAccount();
  Future<void> signOut();
  Future<void> startGuest();
}

class FirebaseAccountSession extends AccountSession {
  FirebaseAccountSession(this._auth) {
    _subscription = _auth.userChanges().listen((_) => notifyListeners());
  }

  final FirebaseAuth _auth;
  late final StreamSubscription<User?> _subscription;
  AuthCredential? _existingCredential;

  @override
  AppAccount? get account {
    final user = _auth.currentUser;
    return user == null
        ? null
        : AppAccount(
            id: user.uid,
            isGuest: user.isAnonymous,
            name: user.displayName,
            email: user.email,
          );
  }

  @override
  Future<void> signInGoogle() async {
    _existingCredential = null;
    final provider = GoogleAuthProvider()
      ..setCustomParameters({'prompt': 'select_account'});
    final user = _auth.currentUser;
    if (user == null || !user.isAnonymous) {
      await _signIn(provider);
      return;
    }
    try {
      // Linking keeps the same UID, so Firestore history stays in place.
      await (kIsWeb
          ? user.linkWithPopup(provider)
          : user.linkWithProvider(provider));
    } on FirebaseAuthException catch (error) {
      if (error.code == 'credential-already-in-use') {
        _existingCredential = error.credential;
        throw const ExistingGoogleAccount();
      }
      rethrow;
    }
  }

  @override
  Future<void> useExistingGoogleAccount() async {
    final credential = _existingCredential;
    _existingCredential = null;
    if (credential != null) {
      await _auth.signInWithCredential(credential);
    } else {
      await _signIn(GoogleAuthProvider());
    }
  }

  // Web uses a popup window; Android opens Google's sign-in in a browser tab.
  Future<void> _signIn(AuthProvider provider) async {
    if (kIsWeb) {
      await _auth.signInWithPopup(provider);
    } else {
      await _auth.signInWithProvider(provider);
    }
  }

  @override
  Future<void> startGuest() async {
    if (_auth.currentUser == null) await _auth.signInAnonymously();
  }

  @override
  Future<void> signOut() async {
    _existingCredential = null;
    await _auth.signOut();
    await startGuest();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

String accountErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'popup-closed-by-user' ||
      'cancelled-popup-request' ||
      'canceled' ||
      'web-context-canceled' =>
        'Sign-in was canceled. Your current history is unchanged.',
      'popup-blocked' =>
        'Allow pop-ups for this site, then try signing in again.',
      'unauthorized-domain' => 'This app address needs to be added to Firebase Authentication authorized domains.',
      'operation-not-allowed' =>
        'Google sign-in needs to be enabled in Firebase Authentication.',
      'network-request-failed' =>
        'Check your internet connection and try again.',
      'account-exists-with-different-credential' => 'This email already uses another sign-in method. Use that method before linking Google.',
      _ => 'Could not complete sign-in. Please try again.',
    };
  }
  return 'Could not complete the account action. Please try again.';
}
