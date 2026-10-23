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
/// is changed), so the choice survives moving between them. Every
/// destination works without signing in.
class SaveSettings extends ChangeNotifier {
  SaveDestination destination = SaveDestination.device;

  void select(SaveDestination d) {
    if (d == destination) return;
    destination = d;
    notifyListeners();
  }
}

/// Pushed from the review screen at any point; Back returns to the review
/// with nothing lost.
class DestinationScreen extends StatelessWidget {
  const DestinationScreen({super.key, required this.settings});

  final SaveSettings settings;

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
                                'We make a calendar file with your dates. '
                                'Pick where it goes; no sign-in needed.',
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
                              onSelect: () => settings.select(d),
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
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: Text('Use $name'),
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
    required this.onSelect,
  });

  final SaveDestination destination;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = switch (destination) {
      SaveDestination.device => (
          'This phone’s calendar',
          'Downloads a calendar file (.ics) that your calendar app opens.',
        ),
      SaveDestination.google => (
          'Google Calendar',
          'Downloads the file and opens Google Calendar’s import page.',
        ),
      SaveDestination.microsoft => (
          'Outlook / Microsoft 365',
          'Downloads the file and opens Outlook’s import page. Works with '
              'school, work and Outlook.com accounts.',
        ),
    };

    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? AppColors.tan.withValues(alpha: 0.1) : AppColors.paper,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
