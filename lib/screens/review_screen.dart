import 'package:flutter/material.dart';

import '../models/syllabus.dart';
import '../theme/app_theme.dart';
import '../widgets/aurora_background.dart';
import 'destination_screen.dart';
import '../widgets/step_header.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _fmtDate(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day}';

/// (badge label, accent, text color)
(String, Color, Color) _typeStyle(EventType t) => switch (t) {
  EventType.exam => ('EXAM', AppColors.clay, AppColors.clay),
  EventType.assignment => ('DUE', AppColors.tan, AppColors.tanDeep),
  EventType.reading => ('READING', AppColors.ochre, const Color(0xFF7A5A12)),
  EventType.project => (
    'PROJECT',
    const Color(0xFF7A5A55),
    const Color(0xFF5E4440),
  ),
};

/// Step 3: confirm what was extracted, fix or re-extract, then choose
/// where to save.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    super.key,
    required this.upload,
    required this.events,
    required this.connected,
    required this.onReparse,
    required this.onConnect,
    required this.onSave,
  });

  final SyllabusUpload upload;
  final List<ExtractedEvent> events;

  /// Destinations that are ready to use right now (the on-device calendar
  /// is normally included; Google / Microsoft need sign-in first).
  final Set<SaveDestination> connected;

  /// Run the extraction again, optionally with the user's note.
  final void Function(String? note) onReparse;

  /// Start sign-in for a linked calendar. Return true once it's linked.
  final Future<bool> Function(SaveDestination destination) onConnect;

  final Future<void> Function(
    List<ExtractedEvent> events,
    SaveDestination destination,
  )
  onSave;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late final List<ExtractedEvent> _events = List.of(widget.events);
  late final SaveSettings _save = SaveSettings(connected: widget.connected);
  final Set<String> _excluded = {};
  final _hint = TextEditingController();
  bool _onlyFlagged = false;
  bool _saving = false;

  Future<void> _saveDates() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(_included, _save.destination);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _hint.dispose();
    _save.dispose();
    super.dispose();
  }

  List<ExtractedEvent> get _included =>
      _events.where((e) => !_excluded.contains(e.id)).toList();

  int get _flaggedCount => _events.where((e) => e.needsReview).length;

  Future<void> _edit(ExtractedEvent event, {bool isNew = false}) async {
    final result = await showModalBottomSheet<_EditResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.sand,
      builder: (_) => _EditSheet(event: event, isNew: isNew),
    );
    if (result == null || !mounted) return;
    setState(() {
      final i = _events.indexWhere((e) => e.id == event.id);
      if (result.delete) {
        if (i >= 0) _events.removeAt(i);
        _excluded.remove(event.id);
      } else if (i >= 0) {
        _events[i] = result.event!;
      } else {
        _events.add(result.event!);
      }
    });
  }

  void _addManually() {
    _edit(
      ExtractedEvent(
        id: 'manual-${DateTime.now().microsecondsSinceEpoch}',
        title: '',
        type: EventType.assignment,
        date: DateTime.now(),
        course: _events.isNotEmpty ? _events.first.course : '',
      ),
      isNew: true,
    );
  }

  void _openDestination() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            DestinationScreen(settings: _save, onConnect: widget.onConnect),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final shown = _onlyFlagged
        ? _events.where((e) => e.needsReview).toList()
        : _events;
    final count = _included.length;

    return PopScope(
      canPop: !_saving,
      child: AbsorbPointer(
        absorbing: _saving,
        child: Scaffold(
          body: AuroraBackground(
            child: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      children: [
                        const StepHeader(step: 3, label: 'Review'),
                        const SizedBox(height: 28),
                        Text(
                          'Review your dates',
                          style: text.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'We found ${_events.length} '
                          '${_events.length == 1 ? 'item' : 'items'} in '
                          '${widget.upload.file.name}. Check each one, then '
                          'save them to your calendar.',
                          style: text.bodyLarge?.copyWith(
                            color: AppColors.stone,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 8,
                          children: [
                            _FilterChip(
                              label: 'All (${_events.length})',
                              selected: !_onlyFlagged,
                              onTap: () => setState(() => _onlyFlagged = false),
                            ),
                            _FilterChip(
                              label: 'Needs a look ($_flaggedCount)',
                              selected: _onlyFlagged,
                              onTap: () => setState(() => _onlyFlagged = true),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (shown.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              'Nothing needs a look right now.',
                              style: TextStyle(color: AppColors.stone),
                            ),
                          ),
                        for (final e in shown)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _EventCard(
                              event: e,
                              included: !_excluded.contains(e.id),
                              onToggle: (v) => setState(() {
                                v
                                    ? _excluded.remove(e.id)
                                    : _excluded.add(e.id);
                              }),
                              onEdit: () => _edit(e),
                            ),
                          ),
                        const SizedBox(height: 2),
                        OutlinedButton.icon(
                          onPressed: _addManually,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add a missing date'),
                        ),
                        const SizedBox(height: 24),
                        _ReparseCard(
                          controller: _hint,
                          onReparse: () {
                            final note = _hint.text.trim();
                            widget.onReparse(note.isEmpty ? null : note);
                          },
                        ),
                      ],
                    ),
                  ),
                  ListenableBuilder(
                    listenable: _save,
                    builder: (context, _) => _SaveBar(
                      count: count,
                      destination: _save.destination,
                      destReady: _save.ready && !_saving,
                      saving: _saving,
                      onChoose: _openDestination,
                      onPressed: _saveDates,
                    ),
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

// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label.toUpperCase(),
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.4,
      color: AppColors.stone,
    ),
  );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onTap(),
    showCheckmark: false,
    selectedColor: AppColors.tan.withValues(alpha: 0.2),
    backgroundColor: AppColors.paper.withValues(alpha: 0.8),
    side: BorderSide(color: selected ? AppColors.tan : AppColors.line),
    labelStyle: TextStyle(
      fontWeight: FontWeight.w600,
      color: selected ? AppColors.tanDeep : AppColors.stone,
    ),
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.included,
    required this.onToggle,
    required this.onEdit,
  });

  final ExtractedEvent event;
  final bool included;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final (label, accent, textColor) = _typeStyle(event.type);
    final flagged = event.needsReview;
    final when = event.time == null
        ? _fmtDate(event.date)
        : '${_fmtDate(event.date)}  ·  ${event.time}';

    return Opacity(
      opacity: included ? 1 : 0.55,
      child: Material(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onEdit,
          child: Container(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: flagged ? AppColors.ochre : AppColors.line,
                width: flagged ? 1.5 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: included,
                  onChanged: (v) => onToggle(v ?? false),
                  activeColor: AppColors.tan,
                  side: const BorderSide(color: AppColors.stone, width: 1.5),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: textColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                event.course,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.stone,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          event.title.isEmpty ? 'Untitled' : event.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.event_outlined,
                              size: 16,
                              color: AppColors.stone,
                            ),
                            const SizedBox(width: 6),
                            Text(when, style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                        if (flagged) ...[
                          const SizedBox(height: 8),
                          const Row(
                            children: [
                              Icon(
                                Icons.flag_rounded,
                                size: 16,
                                color: AppColors.clay,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Check this one. We weren’t sure.',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.clay,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (event.sourceQuote != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                            decoration: const BoxDecoration(
                              color: AppColors.sand,
                              border: Border(
                                left: BorderSide(
                                  color: AppColors.camel,
                                  width: 3,
                                ),
                              ),
                            ),
                            child: Text(
                              'In your syllabus: “${event.sourceQuote}”',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                height: 1.35,
                                color: AppColors.stone,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Edit',
                  onPressed: onEdit,
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 20,
                    color: AppColors.stone,
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

class _ReparseCard extends StatelessWidget {
  const _ReparseCard({required this.controller, required this.onReparse});

  final TextEditingController controller;
  final VoidCallback onReparse;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.refresh_rounded, color: AppColors.tanDeep),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Missing something, or something wrong?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Tell us what to look for and we’ll read the syllabus again. '
            'This replaces the list above, including any edits you made.',
            style: TextStyle(fontSize: 14, color: AppColors.stone, height: 1.4),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            minLines: 2,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'e.g. You missed the final exam on Dec 8',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onReparse,
            child: const Text('Extract again'),
          ),
        ],
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.count,
    required this.destination,
    required this.destReady,
    required this.onChoose,
    required this.onPressed,
    this.saving = false,
  });

  final int count;
  final SaveDestination destination;
  final bool destReady;
  final VoidCallback onChoose;
  final VoidCallback onPressed;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final ready = count > 0 && destReady;
    final name = saveDestinationName(destination);
    final title = switch (destination) {
      SaveDestination.device => 'Phone calendar',
      SaveDestination.google => 'Google Calendar',
      SaveDestination.microsoft => 'Outlook / Microsoft 365',
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      decoration: const BoxDecoration(
        color: AppColors.sand,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            label: 'Saving to $title. Change where to save.',
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onChoose,
              child: Container(
                constraints: const BoxConstraints(minHeight: 52),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Icon(
                      saveDestinationIcon(destination),
                      size: 22,
                      color: AppColors.tanDeep,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SAVING TO',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: AppColors.stone,
                            ),
                          ),
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!destReady) ...[
                      const Text(
                        'Not linked',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.clay,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    const Text(
                      'Change',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.tan,
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.tan,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          FilledButton(
            onPressed: ready ? onPressed : null,
            child: Text(
              saving
                  ? 'Saving dates…'
                  : count == 0
                  ? 'Nothing selected'
                  : 'Add $count ${count == 1 ? 'date' : 'dates'} to $name',
            ),
          ),
          if (!ready && !saving) ...[
            const SizedBox(height: 8),
            Text(
              count == 0
                  ? 'Select at least one date to continue'
                  : 'Connect $name to continue',
              style: const TextStyle(fontSize: 13, color: AppColors.stone),
            ),
          ],
        ],
      ),
    );
  }
}

// --- Edit sheet ------------------------------------------------------------

class _EditResult {
  const _EditResult.save(ExtractedEvent this.event) : delete = false;
  const _EditResult.delete() : event = null, delete = true;

  final ExtractedEvent? event;
  final bool delete;
}

class _EditSheet extends StatefulWidget {
  const _EditSheet({required this.event, required this.isNew});

  final ExtractedEvent event;
  final bool isNew;

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final _title = TextEditingController(text: widget.event.title);
  late final _course = TextEditingController(text: widget.event.course);
  late EventType _type = widget.event.type;
  late DateTime _date = widget.event.date;
  late String? _time = widget.event.time;

  @override
  void dispose() {
    _title.dispose();
    _course.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final first = DateTime(now.year - 1);
    final last = DateTime(now.year + 3, 12, 31);
    final initial = _date.isBefore(first)
        ? first
        : _date.isAfter(last)
        ? last
        : _date;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null && mounted) {
      setState(() {
        _time = MaterialLocalizations.of(context).formatTimeOfDay(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final canSave = _title.text.trim().isNotEmpty;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.isNew ? 'Add a date' : 'Edit date',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _course,
            decoration: const InputDecoration(labelText: 'Course'),
          ),
          const SizedBox(height: 16),
          const _SectionLabel('Type'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final t in EventType.values)
                _FilterChip(
                  label: switch (t) {
                    EventType.exam => 'Exam',
                    EventType.assignment => 'Assignment',
                    EventType.reading => 'Reading',
                    EventType.project => 'Project',
                  },
                  selected: _type == t,
                  onTap: () => setState(() => _type = t),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _PickerField(
                  label: 'Date',
                  value: _fmtDate(_date),
                  icon: Icons.calendar_today_outlined,
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PickerField(
                  label: 'Time',
                  value: _time ?? 'All day',
                  icon: _time == null ? Icons.schedule : Icons.close_rounded,
                  onTap: _pickTime,
                  onIconTap: _time == null
                      ? null
                      : () => setState(() => _time = null),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: canSave
                ? () => Navigator.of(context).pop(
                    _EditResult.save(
                      widget.event.copyWith(
                        title: _title.text.trim(),
                        course: _course.text.trim(),
                        type: _type,
                        date: _date,
                        time: _time,
                        clearTime: _time == null,
                      ),
                    ),
                  )
                : null,
            child: Text(widget.isNew ? 'Add date' : 'Save changes'),
          ),
          if (!widget.isNew) ...[
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(const _EditResult.delete()),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Delete this date'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.onIconTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onIconTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: onIconTap == null
              ? Icon(icon, size: 20)
              : IconButton(
                  tooltip: 'Clear time',
                  onPressed: onIconTap,
                  icon: Icon(icon, size: 20),
                ),
        ),
        child: Text(value, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}
