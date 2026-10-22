import 'dart:async';

import 'package:flutter/material.dart';

import '../models/syllabus.dart';
import '../services/syllabus_extractor.dart';
import '../theme/app_theme.dart';
import '../widgets/aurora_background.dart';
import '../widgets/step_header.dart';

/// Step 2: runs the extraction in-app and shows progress. The user never
/// leaves the app; backing out or tapping Cancel stops the request.
class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({
    super.key,
    required this.upload,
    required this.extractor,
    required this.onDone,
  });

  final SyllabusUpload upload;
  final SyllabusExtractor extractor;
  final void Function(List<ExtractedEvent> events) onDone;

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

const _stageLabels = {
  ExtractionStage.uploading: 'Sending your file securely',
  ExtractionStage.reading: 'Reading the document',
  ExtractionStage.finding: 'Finding dates and deadlines',
  ExtractionStage.checking: 'Double-checking the results',
};

class _ProcessingScreenState extends State<ProcessingScreen> {
  StreamSubscription<ExtractionUpdate>? _sub;
  ExtractionStage _stage = ExtractionStage.uploading;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  void _retry() {
    setState(() {
      _stage = ExtractionStage.uploading;
      _error = null;
    });
    _listen();
  }

  void _listen() {
    _sub?.cancel();
    _sub = widget.extractor.extract(widget.upload).listen(
      (update) {
        if (!mounted) return;
        switch (update) {
          case StageReached(:final stage):
            setState(() => _stage = stage);
          case ExtractionComplete(:final events):
            widget.onDone(events);
        }
      },
      onError: (Object e) {
        if (mounted) setState(() => _error = e);
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel(); // cancels the in-flight request if the user leaves
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final failed = _error != null;

    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const StepHeader(step: 2, label: 'Extract'),
                      const SizedBox(height: 28),
                      Text(
                        failed ? 'That didn’t work' : 'Reading your syllabus',
                        style: text.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        failed
                            ? '${_error is ExtractionException ? '$_error ' : 'We couldn’t finish reading this file. '}'
                                'Your details are saved, so you can try again.'
                            : 'This usually takes under a minute. '
                                'You’ll review every date before it’s added.',
                        style: text.bodyLarge?.copyWith(
                          color: AppColors.stone,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _FileChip(name: widget.upload.file.name),
                      const SizedBox(height: 24),
                      _StageList(current: _stage, failed: failed),
                    ],
                  ),
                ),
              ),
              _Actions(
                failed: failed,
                onRetry: _retry,
                onCancel: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileChip extends StatelessWidget {
  const _FileChip({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.paper.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'PDF',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: AppColors.clay,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _StageList extends StatelessWidget {
  const _StageList({required this.current, required this.failed});

  final ExtractionStage current;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          for (final stage in ExtractionStage.values)
            _StageRow(
              label: _stageLabels[stage]!,
              state: stage.index < current.index
                  ? _RowState.done
                  : stage == current
                      ? (failed ? _RowState.failed : _RowState.active)
                      : _RowState.pending,
              isLast: stage == ExtractionStage.values.last,
            ),
        ],
      ),
    );
  }
}

enum _RowState { done, active, pending, failed }

class _StageRow extends StatelessWidget {
  const _StageRow({
    required this.label,
    required this.state,
    required this.isLast,
  });

  final String label;
  final _RowState state;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final Widget icon = switch (state) {
      _RowState.done =>
        const Icon(Icons.check_circle, size: 22, color: AppColors.tan),
      _RowState.active => const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.tan,
          ),
        ),
      _RowState.failed =>
        const Icon(Icons.error_outline, size: 22, color: AppColors.error),
      _RowState.pending =>
        const Icon(Icons.circle_outlined, size: 22, color: AppColors.line),
    };

    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          SizedBox(width: 24, height: 24, child: Center(child: icon)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight:
                    state == _RowState.active || state == _RowState.failed
                        ? FontWeight.w700
                        : FontWeight.w500,
                color: state == _RowState.pending
                    ? AppColors.stone
                    : AppColors.bark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.failed,
    required this.onRetry,
    required this.onCancel,
  });

  final bool failed;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        color: AppColors.sand,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: failed
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton(onPressed: onRetry, child: const Text('Try again')),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: onCancel,
                  child: const Text('Back to upload'),
                ),
              ],
            )
          : OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                foregroundColor: AppColors.tanDeep,
                side: const BorderSide(color: AppColors.tan, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Cancel'),
            ),
    );
  }
}
