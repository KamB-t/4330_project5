import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'models/syllabus.dart';
import 'screens/processing_screen.dart';
import 'screens/review_screen.dart';
import 'screens/upload_screen.dart';
import 'screens/history_screen.dart';
import 'screens/account_screen.dart';
import 'services/account_session.dart';
import 'services/syllabus_extractor.dart';
import 'services/upload_history.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FirebaseBootstrap());
}

class FirebaseBootstrap extends StatefulWidget {
  const FirebaseBootstrap({super.key});

  @override
  State<FirebaseBootstrap> createState() => _FirebaseBootstrapState();
}

class _FirebaseBootstrapState extends State<FirebaseBootstrap> {
  late Future<FirebaseAccountSession> _setup = _connect();
  FirebaseAccountSession? _session;
  final Map<String, UploadHistoryStore> _stores = {};

  Future<FirebaseAccountSession> _connect() async {
    if (!kIsWeb) throw UnsupportedError('Firebase is configured for web only.');
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: firebaseWebOptions);
    }
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) await auth.signInAnonymously();
    return _session ??= FirebaseAccountSession(auth);
  }

  @override
  void dispose() {
    _session?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<FirebaseAccountSession>(
    future: _setup,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        final session = snapshot.data!;
        return AnimatedBuilder(
          animation: session,
          builder: (context, _) {
            final account = session.account;
            if (account == null) {
              return MaterialApp(
                theme: buildAppTheme(),
                home: Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('You are signed out.'),
                        FilledButton(
                          onPressed: () => setState(() => _setup = _connect()),
                          child: const Text('Continue as guest'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            return SyllabusApp(
              // An identity switch discards routes, form state and old history.
              key: ValueKey(account.id),
              accountSession: session,
              historyStore: _stores.putIfAbsent(
                account.id,
                () => FirestoreUploadHistory(
                  FirebaseFirestore.instance,
                  account.id,
                ),
              ),
            );
          },
        );
      }
      return MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: snapshot.hasError
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Could not connect to your history. Check your connection and Firebase setup. Use Chrome; other platforms are not configured yet.',
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => setState(() => _setup = _connect()),
                          child: const Text('Retry'),
                        ),
                      ],
                    )
                  : const CircularProgressIndicator(),
            ),
          ),
        ),
      );
    },
  );
}

class SyllabusApp extends StatelessWidget {
  const SyllabusApp({
    super.key,
    this.extractor = const MockSyllabusExtractor(),
    this.historyStore,
    this.accountSession,
  });

  /// Swap in the real LLM-backed extractor when it exists.
  final SyllabusExtractor extractor;
  final UploadHistoryStore? historyStore;
  final AccountSession? accountSession;

  // Step 2: extraction. On success it replaces itself with the review.
  Route<void> _processing(BuildContext context, SyllabusUpload upload) {
    final nav = Navigator.of(context);
    return MaterialPageRoute<void>(
      builder: (_) => ProcessingScreen(
        upload: upload,
        extractor: extractor,
        onDone: (events) =>
            nav.pushReplacement(_review(context, upload, events)),
      ),
    );
  }

  // Step 3: review, re-extract, choose destination, save.
  Route<void> _review(
    BuildContext context,
    SyllabusUpload upload,
    List<ExtractedEvent> events,
  ) {
    final nav = Navigator.of(context);
    return MaterialPageRoute<void>(
      builder: (_) => ReviewScreen(
        upload: upload,
        events: events,
        connected: const {SaveDestination.device},
        onReparse: (note) => nav.pushReplacement(
          _processing(context, upload.copyWith(hint: note)),
        ),
        // App sign-in does not grant permission to write to Google Calendar.
        // TODO: real calendar authorization for Google / Microsoft.
        onConnect: (destination) async {
          await Future<void>.delayed(const Duration(milliseconds: 900));
          return true;
        },
        // TODO: write to the device calendar or the linked account.
        onSave: (saved, destination) {
          nav.popUntil((route) => route.isFirst);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Saved ${saved.length} dates (mock).')),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Syllabus to Calendar',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: Builder(
        builder: (context) => _UploadHome(
          historyStore: historyStore,
          accountSession: accountSession,
          // TODO: replace with a real picker (e.g. file_picker, PDF only).
          onPickFile: () async => const PickedSyllabus(
            name: 'BIO_2310_Syllabus_Fall2026.pdf',
            sizeBytes: 421888,
          ),
          onExtract: (upload) =>
              Navigator.of(context).push(_processing(context, upload)),
        ),
      ),
    );
  }
}

class _UploadHome extends StatefulWidget {
  const _UploadHome({
    required this.onPickFile,
    required this.onExtract,
    this.historyStore,
    this.accountSession,
  });

  final Future<PickedSyllabus?> Function() onPickFile;
  final void Function(SyllabusUpload) onExtract;
  final UploadHistoryStore? historyStore;
  final AccountSession? accountSession;

  @override
  State<_UploadHome> createState() => _UploadHomeState();
}

class _UploadHomeState extends State<_UploadHome> {
  int _tab = 0;
  List<UploadHistoryEntry> _history = [];
  late final UploadHistoryStore _store;
  StreamSubscription<List<UploadHistoryEntry>>? _subscription;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _store = widget.historyStore ?? MemoryUploadHistory();
    _subscription = _store.watch().listen(
      (entries) {
        if (!mounted) return;
        setState(() {
          _history = entries;
          _loading = false;
          _error = null;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Could not load history. Check your connection and try reopening the app.';
        });
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _extract(SyllabusUpload upload) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _store.add(upload);
      if (mounted) widget.onExtract(upload);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save upload history. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        AbsorbPointer(
          absorbing: _saving,
          child: IndexedStack(
            index: _tab,
            children: [
              UploadScreen(onPickFile: widget.onPickFile, onExtract: _extract),
              HistoryScreen(
                entries: _history,
                loading: _loading,
                error: _error,
                onUpload: () => setState(() => _tab = 0),
                onExtract: _extract,
                signedIn: widget.accountSession?.account?.isGuest == false,
              ),
              if (widget.accountSession != null)
                AccountScreen(session: widget.accountSession!),
            ],
          ),
        ),
        if (_saving)
          const Align(
            alignment: Alignment.topCenter,
            child: SafeArea(child: LinearProgressIndicator()),
          ),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _tab,
      onDestinationSelected: (index) => setState(() => _tab = index),
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.upload_file_outlined),
          label: 'Upload',
        ),
        const NavigationDestination(
          icon: Icon(Icons.history_rounded),
          label: 'History',
        ),
        if (widget.accountSession != null)
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            label: 'Account',
          ),
      ],
    ),
  );
}
