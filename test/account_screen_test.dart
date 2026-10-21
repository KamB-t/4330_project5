import 'package:app5/screens/account_screen.dart';
import 'package:app5/services/account_session.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAccountSession extends AccountSession {
  AppAccount? current = const AppAccount(id: 'guest-1', isGuest: true);
  Object? error;
  int existingSignIns = 0;

  @override
  AppAccount? get account => current;
  @override
  Future<void> signInGoogle() async {
    if (error != null) throw error!;
    current = AppAccount(
      id: current!.id,
      isGuest: false,
      name: 'Student',
      email: 'student@example.com',
    );
    notifyListeners();
  }

  @override
  Future<void> useExistingGoogleAccount() async {
    existingSignIns++;
    current = const AppAccount(id: 'existing-user', isGuest: false);
    notifyListeners();
  }

  @override
  Future<void> signOut() async {
    current = const AppAccount(id: 'new-guest', isGuest: true);
    notifyListeners();
  }

  @override
  Future<void> startGuest() async {}
}

Future<void> showAccount(
  WidgetTester tester,
  FakeAccountSession session,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: AccountScreen(session: session)),
    ),
  );
}

void main() {
  testWidgets(
    'Linking displays account details and retains the guest identity',
    (tester) async {
      final session = FakeAccountSession();
      await showAccount(tester, session);
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();
      expect(session.account!.id, 'guest-1');
      expect(find.text('student@example.com'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(session.account!.id, 'new-guest');
      expect(find.text('Continue with Google'), findsOneWidget);
    },
  );

  testWidgets('Existing account requires an explicit choice before switching', (
    tester,
  ) async {
    final session = FakeAccountSession()..error = const ExistingGoogleAccount();
    await showAccount(tester, session);
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stay as guest'));
    await tester.pumpAndSettle();
    expect(session.account!.id, 'guest-1');
    expect(session.existingSignIns, 0);
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use existing account'));
    await tester.pumpAndSettle();
    expect(session.account!.id, 'existing-user');
    expect(session.existingSignIns, 1);
  });

  testWidgets(
    'Canceling Google sign-in keeps the guest session and permits retry',
    (tester) async {
      final session = FakeAccountSession()
        ..error = FirebaseAuthException(code: 'popup-closed-by-user');
      await showAccount(tester, session);
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();
      expect(session.account!.id, 'guest-1');
      expect(
        find.text('Sign-in was canceled. Your current history is unchanged.'),
        findsOneWidget,
      );
      session.error = null;
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();
      expect(session.account!.isGuest, false);
    },
  );
}
