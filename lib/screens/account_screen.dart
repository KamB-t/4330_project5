import 'package:flutter/material.dart';

import '../services/account_session.dart';
import '../theme/app_theme.dart';
import '../widgets/aurora_background.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, required this.session});
  final AccountSession session;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _busy = false;
  String? _message;

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.session.signInGoogle();
      if (mounted) {
        setState(
          () => _message = 'Signed in. Your history is saved to your account.',
        );
      }
    } on ExistingGoogleAccount {
      if (!mounted) return;
      setState(() => _busy = false);
      final useExisting = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Use your existing account?'),
          content: const Text(
            'This Google account already has an app account. Signing in will show its history. Uploads from this guest session will remain separate and will not be transferred. Stay as a guest to keep accessing them here.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Stay as guest'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Use existing account'),
            ),
          ],
        ),
      );
      if (useExisting == true && mounted) {
        setState(() => _busy = true);
        try {
          await widget.session.useExistingGoogleAccount();
        } catch (error) {
          if (mounted) setState(() => _message = accountErrorMessage(error));
        }
      }
    } catch (error) {
      if (mounted) setState(() => _message = accountErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.session.signOut();
    } catch (error) {
      if (mounted) setState(() => _message = accountErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.session,
    builder: (context, _) {
      final account = widget.session.account;
      final guest = account?.isGuest ?? true;
      return AuroraBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Account',
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        guest
                            ? Icons.person_outline_rounded
                            : Icons.verified_user_outlined,
                        size: 40,
                        color: AppColors.tan,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        guest
                            ? 'You’re using a guest account'
                            : (account?.name ?? 'Signed in with Google'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (!guest && account?.email != null) ...[
                        const SizedBox(height: 8),
                        Text(account!.email!),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        guest
                            ? 'Sign in with Google to keep your upload history and access it on other devices. Linking a new account keeps your current uploads.'
                            : 'Your upload history is linked to this account. Sign in with the same Google account on another device to see it.',
                      ),
                      const SizedBox(height: 24),
                      if (guest)
                        FilledButton.icon(
                          onPressed: _busy ? null : _signIn,
                          icon: const Icon(Icons.login_rounded),
                          label: const Text('Continue with Google'),
                        )
                      else ...[
                        OutlinedButton(
                          onPressed: _busy ? null : _signOut,
                          child: const Text('Sign out'),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Signing out starts a new guest session. Your account history stays saved.',
                          style: TextStyle(color: AppColors.stone),
                        ),
                      ],
                      if (_busy) ...[
                        const SizedBox(height: 16),
                        const LinearProgressIndicator(),
                      ],
                      if (_message != null) ...[
                        const SizedBox(height: 16),
                        Text(_message!, semanticsLabel: _message),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
