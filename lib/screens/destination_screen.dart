import 'package:flutter/material.dart';

import '../models/syllabus.dart';
import '../theme/app_theme.dart';
import '../widgets/aurora_background.dart';

String saveDestinationName(SaveDestination d) => switch (d) {
  SaveDestination.device => 'phone calendar',
  SaveDestination.google => 'Google Calendar',
  SaveDestination.microsoft => 'Outlook',
};

IconData saveDestinationIcon(SaveDestination d) => switch (d) {
  SaveDestination.device => Icons.smartphone_rounded,
  SaveDestination.google => Icons.event_available_outlined,
  SaveDestination.microsoft => Icons.cloud_outlined,
};

/// Where the confirmed dates will be saved. Shared by the review screen
/// (which shows the current choice) and the destination screen (where it
/// is changed), so the choice and sign-in state survive moving between them.
class SaveSettings extends ChangeNotifier {
  SaveSettings({
    Set<SaveDestination> connected = const {SaveDestination.device},
  }) : connected = {...connected};

  SaveDestination destination = SaveDestination.device;
  final Set<SaveDestination> connected;
  SaveDestination? connecting;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  bool get ready => connected.contains(destination);

  void select(SaveDestination d) {
    destination = d;
    notifyListeners();
  }

  Future<void> connect(
    SaveDestination d,
    Future<bool> Function(SaveDestination) signIn,
  ) async {
    if (connecting != null) return;
    connecting = d;
    notifyListeners();
    try {
      final ok = await signIn(d);
      if (ok) connected.add(d);
    } finally {
      connecting = null;
      if (!_disposed) notifyListeners();
    }
  }
}

/// Pushed from the review screen at any point; Back returns to the review
/// with nothing lost.
class DestinationScreen extends StatelessWidget {
  const DestinationScreen({
    super.key,
    required this.settings,
    required this.onConnect,
  });

  final SaveSettings settings;
  final Future<bool> Function(SaveDestination destination) onConnect;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: ListenableBuilder(
            listenable: settings,
            builder: (context, _) {
              final name = saveDestinationName(settings.destination);
              return Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(8, 8, 20, 24),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            tooltip: 'Back to review',
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 12, top: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Where to save',
                                style: text.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Your dates go to the calendar you pick. '
                                'You can change this any time before saving.',
                                style: text.bodyLarge?.copyWith(
                                  color: AppColors.stone,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                        for (final d in SaveDestination.values)
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 12,
                              bottom: 10,
                            ),
                            child: DestinationTile(
                              destination: d,
                              selected: settings.destination == d,
                              connected: settings.connected.contains(d),
                              connecting: settings.connecting == d,
                              onSelect: () => settings.select(d),
                              onConnect: () => settings.connect(d, onConnect),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    decoration: const BoxDecoration(
                      color: AppColors.sand,
                      border: Border(top: BorderSide(color: AppColors.line)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FilledButton(
                          onPressed: settings.ready
                              ? () => Navigator.of(context).maybePop()
                              : null,
                          child: Text('Use $name'),
                        ),
                        if (!settings.ready) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Connect $name to continue',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.stone,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class DestinationTile extends StatelessWidget {
  const DestinationTile({
    super.key,
    required this.destination,
    required this.selected,
    required this.connected,
    required this.connecting,
    required this.onSelect,
    required this.onConnect,
  });

  final SaveDestination destination;
  final bool selected;
  final bool connected;
  final bool connecting;
  final VoidCallback onSelect;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = switch (destination) {
      SaveDestination.device => (
        'This phone’s calendar',
        'Saves to the calendar app on this device. No sign-in needed.',
      ),
      SaveDestination.google => (
        'Google Calendar',
        connected
            ? 'Saves selected dates directly to your primary calendar.'
            : 'Allow Termwise to add dates to your primary Google calendar.',
      ),
      SaveDestination.microsoft => (
        'Outlook / Microsoft 365',
        connected
            ? 'Account linked. Syncs to all your devices.'
            : 'Sign in with your school or work account.',
      ),
    };

    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected
            ? AppColors.tan.withValues(alpha: 0.1)
            : AppColors.paper,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onSelect,
          child: Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? AppColors.tan : AppColors.line,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected ? AppColors.tan : AppColors.stone,
                ),
                const SizedBox(width: 12),
                Icon(
                  saveDestinationIcon(destination),
                  size: 24,
                  color: AppColors.tanDeep,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.3,
                          color: AppColors.stone,
                        ),
                      ),
                    ],
                  ),
                ),
                if (connecting)
                  const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.tan,
                      ),
                    ),
                  )
                else if (!connected)
                  TextButton(onPressed: onConnect, child: const Text('Connect'))
                else if (destination != SaveDestination.device)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(
                      Icons.check_circle,
                      size: 20,
                      color: AppColors.tan,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
