import 'package:flutter/material.dart';

import '../models/syllabus.dart';
import '../theme/app_theme.dart';
import '../widgets/aurora_background.dart';
import '../widgets/step_header.dart';

const _timeZones = <String>[
  'Eastern (ET)',
  'Central (CT)',
  'Mountain (MT)',
  'Pacific (PT)',
  'Alaska (AKT)',
  'Hawaii (HT)',
];

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key, required this.onPickFile, this.onExtract});

  /// Opens the system file picker (PDF only) and returns the choice,
  /// or null if the user cancelled.
  final Future<PickedSyllabus?> Function() onPickFile;

  /// Called when the user taps "Extract dates" with a complete form.
  final void Function(SyllabusUpload upload)? onExtract;

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  PickedSyllabus? _file;
  DateTime? _start;
  String _zone = _timeZones[1];

  bool get _ready => _file != null && _start != null;

  bool _picking = false;

  Future<void> _pick() async {
    if (_picking) return; // a second tap while the picker is open would fail
    setState(() => _picking = true);
    try {
      final picked = await widget.onPickFile();
      if (picked != null && mounted) setState(() => _file = picked);
    } on SyllabusFileException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('Could not open the file picker. Please try again.');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // Flutter's date picker has a year list but no month list, so choosing a
  // year leaves you on the same month with only arrows to move. Ask for the
  // year and month first, then show the usual calendar for picking the day.
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final first = DateTime(now.year - 1);
    final last = DateTime(now.year + 1, 12, 31);
    final current = _start ?? now;

    final month = await _pickYearAndMonth(current, first.year, last.year);
    if (month == null || !mounted) return;

    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(
        month.year,
        month.month,
        current.day > daysInMonth ? daysInMonth : current.day,
      ),
      firstDate: first,
      lastDate: last,
      helpText: 'SEMESTER START DATE',
    );
    if (date != null && mounted) setState(() => _start = date);
  }

  /// Returns the first day of the chosen month, or null if cancelled.
  Future<DateTime?> _pickYearAndMonth(
    DateTime current,
    int firstYear,
    int lastYear,
  ) {
    var year = current.year;
    return showDialog<DateTime>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Semester start'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      tooltip: 'Previous year',
                      onPressed: year > firstYear
                          ? () => setDialogState(() => year--)
                          : null,
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Text(
                      '$year',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    IconButton(
                      tooltip: 'Next year',
                      onPressed: year < lastYear
                          ? () => setDialogState(() => year++)
                          : null,
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var m = 1; m <= 12; m++)
                      ChoiceChip(
                        label: Text(_months[m - 1]),
                        selected: year == current.year && m == current.month,
                        onSelected: (_) =>
                            Navigator.pop(dialogContext, DateTime(year, m)),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (!_ready) return;
    widget.onExtract?.call(
      SyllabusUpload(file: _file!, semesterStart: _start!, timeZone: _zone),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

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
                      const StepHeader(step: 1, label: 'Upload'),
                      const SizedBox(height: 28),
                      Text(
                        'Add your syllabus',
                        style: text.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'We pull out due dates, exams and readings. '
                        'You review everything before it reaches your calendar.',
                        style: text.bodyLarge?.copyWith(
                          color: AppColors.stone,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _file == null
                          ? _DropZone(onTap: _pick)
                          : _FileCard(
                              file: _file!,
                              onReplace: _pick,
                              onRemove: () => setState(() => _file = null),
                            ),
                      const SizedBox(height: 28),
                      const _SectionLabel('Semester details'),
                      const SizedBox(height: 10),
                      _DateField(value: _start, onTap: _pickDate),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _zone,
                        decoration: const InputDecoration(labelText: 'Time zone'),
                        items: [
                          for (final z in _timeZones)
                            DropdownMenuItem(value: z, child: Text(z)),
                        ],
                        onChanged: (z) => setState(() => _zone = z ?? _zone),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Helps us place dates like “Week 3, Tuesday”.',
                        style: text.bodySmall?.copyWith(color: AppColors.stone),
                      ),
                      const SizedBox(height: 24),
                      const _PrivacyNote(),
                    ],
                  ),
                ),
              ),
              _ActionBar(ready: _ready, onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
        color: AppColors.stone,
      ),
    );
  }
}

class _DropZone extends StatelessWidget {
  const _DropZone({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Choose a syllabus PDF',
      child: CustomPaint(
        painter: const _DashedBorderPainter(color: AppColors.tan, radius: 16),
        child: Material(
          color: AppColors.paper.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.camel.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.upload_file_rounded,
                      size: 30,
                      color: AppColors.tanDeep,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Choose a PDF',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tap to browse  ·  PDF up to 5 MB',
                    style: TextStyle(fontSize: 14, color: AppColors.stone),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FileCard extends StatelessWidget {
  const _FileCard({
    required this.file,
    required this.onReplace,
    required this.onRemove,
  });

  final PickedSyllabus file;
  final VoidCallback onReplace;
  final VoidCallback onRemove;

  static String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.tan, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.clay.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: const Text(
              'PDF',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: AppColors.clay,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _size(file.sizeBytes),
                  style: const TextStyle(fontSize: 13, color: AppColors.stone),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.check_circle, size: 14, color: AppColors.tan),
                    SizedBox(width: 4),
                    Text(
                      'Ready',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.tan,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          TextButton(onPressed: onReplace, child: const Text('Replace')),
          IconButton(
            tooltip: 'Remove file',
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, color: AppColors.stone),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.value, required this.onTap});

  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = value == null
        ? 'Select a date'
        : '${_months[value!.month - 1]} ${value!.day}, ${value!.year}';

    return Semantics(
      button: true,
      label: 'Semester start date, $label',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Semester start date',
            suffixIcon: Icon(Icons.calendar_today_outlined, size: 20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: value == null ? AppColors.stone : AppColors.bark,
            ),
          ),
        ),
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.stone),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Your file is only used to read dates and isn’t stored after extraction.',
            style: TextStyle(fontSize: 13, color: AppColors.stone, height: 1.4),
          ),
        ),
      ],
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.ready, required this.onPressed});

  final bool ready;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        color: AppColors.sand,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton(
            onPressed: ready ? onPressed : null,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Extract dates'),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 20),
              ],
            ),
          ),
          if (!ready) ...[
            const SizedBox(height: 8),
            const Text(
              'Add a PDF and a start date to continue',
              style: TextStyle(fontSize: 13, color: AppColors.stone),
            ),
          ],
        ],
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 8), paint);
        distance += 8 + 6;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
