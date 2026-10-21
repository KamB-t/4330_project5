import 'package:flutter/material.dart';

import '../models/syllabus.dart';
import '../services/upload_history.dart';
import '../theme/app_theme.dart';
import '../widgets/aurora_background.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({
    super.key,
    required this.entries,
    required this.onUpload,
    required this.onExtract,
    this.loading = false,
    this.error,
    this.signedIn = false,
  });

  final List<UploadHistoryEntry> entries;
  final VoidCallback onUpload;
  final ValueChanged<SyllabusUpload> onExtract;
  final bool loading;
  final String? error;
  final bool signedIn;

  String _date(BuildContext context, DateTime date) =>
      MaterialLocalizations.of(context).formatMediumDate(date);

  @override
  Widget build(BuildContext context) => AuroraBackground(
    child: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Upload history',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            signedIn
                ? 'Your latest 20 syllabus submissions, newest first. Saved to your account and available wherever you sign in.'
                : 'Your latest 20 syllabus submissions, newest first. Sign in from the Account tab to keep your history across devices. Clearing browser data resets your guest account.',
            style: const TextStyle(color: AppColors.stone),
          ),
          const SizedBox(height: 24),
          if (loading) const Center(child: CircularProgressIndicator()),
          if (error != null)
            Text(error!, style: const TextStyle(color: AppColors.error)),
          if (!loading && error == null && entries.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(
                      Icons.history_rounded,
                      size: 48,
                      color: AppColors.tan,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No uploads yet',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Submit a syllabus to extract dates and it will appear here.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: onUpload,
                      child: const Text('Upload a syllabus'),
                    ),
                  ],
                ),
              ),
            ),
          for (final entry in entries)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.picture_as_pdf_outlined,
                      color: AppColors.clay,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      entry.upload.file.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Uploaded ${_date(context, entry.uploadedAt)} at ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(entry.uploadedAt))}',
                    ),
                    Text(
                      'Semester starts ${_date(context, entry.upload.semesterStart)}',
                    ),
                    Text(
                      entry.upload.timeZone,
                      style: const TextStyle(color: AppColors.stone),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => onExtract(entry.upload),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Extract again'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
