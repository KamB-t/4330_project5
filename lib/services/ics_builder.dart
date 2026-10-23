import 'dart:convert';

import '../models/syllabus.dart';

/// Parses a clock time such as "2:00 PM", "11:59pm", "2 p.m.", "14:30" or
/// "noon". For a range ("2:00 PM - 3:15 PM") only the start is used. Returns
/// null when it can't be read, and the event becomes an all-day event.
({int hour, int minute})? parseClockTime(String? raw) {
  if (raw == null) return null;
  var text = raw.trim().toLowerCase();
  if (text.isEmpty) return null;
  text = text.split(RegExp(r'\s*[-–—]\s*')).first.trim();
  if (text == 'noon') return (hour: 12, minute: 0);

  final twelveHour = RegExp(
    r'^(\d{1,2})(?::(\d{2}))?\s*([ap])\.?\s*m?\.?$',
  ).firstMatch(text);
  if (twelveHour != null) {
    final h = int.parse(twelveHour.group(1)!);
    final m = int.parse(twelveHour.group(2) ?? '0');
    if (h < 1 || h > 12 || m > 59) return null;
    final pm = twelveHour.group(3) == 'p';
    return (hour: h % 12 + (pm ? 12 : 0), minute: m);
  }

  final twentyFourHour = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(text);
  if (twentyFourHour != null) {
    final h = int.parse(twentyFourHour.group(1)!);
    final m = int.parse(twentyFourHour.group(2)!);
    if (h > 23 || m > 59) return null;
    return (hour: h, minute: m);
  }
  return null;
}

/// A time zone the upload screen offers, with the US daylight-saving rules
/// (since 2007) written into the file. Including the rules means every
/// calendar app places the events correctly without needing its own zone data.
class _Zone {
  const _Zone(this.tzid, this.stdName, this.stdOffset, [this.dstName, this.dstOffset]);

  final String tzid;
  final String stdName;
  final String stdOffset;
  final String? dstName;
  final String? dstOffset;

  List<String> get vtimezone => [
        'BEGIN:VTIMEZONE',
        'TZID:$tzid',
        if (dstName != null) ...[
          'BEGIN:DAYLIGHT',
          'TZOFFSETFROM:$stdOffset',
          'TZOFFSETTO:$dstOffset',
          'TZNAME:$dstName',
          'DTSTART:19700308T020000',
          'RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=2SU',
          'END:DAYLIGHT',
          'BEGIN:STANDARD',
          'TZOFFSETFROM:$dstOffset',
          'TZOFFSETTO:$stdOffset',
          'TZNAME:$stdName',
          'DTSTART:19701101T020000',
          'RRULE:FREQ=YEARLY;BYMONTH=11;BYDAY=1SU',
          'END:STANDARD',
        ] else ...[
          'BEGIN:STANDARD',
          'TZOFFSETFROM:$stdOffset',
          'TZOFFSETTO:$stdOffset',
          'TZNAME:$stdName',
          'DTSTART:19700101T000000',
          'END:STANDARD',
        ],
        'END:VTIMEZONE',
      ];
}

// Keys match the labels on the upload screen.
const _zones = <String, _Zone>{
  'Eastern (ET)': _Zone('America/New_York', 'EST', '-0500', 'EDT', '-0400'),
  'Central (CT)': _Zone('America/Chicago', 'CST', '-0600', 'CDT', '-0500'),
  'Mountain (MT)': _Zone('America/Denver', 'MST', '-0700', 'MDT', '-0600'),
  'Pacific (PT)': _Zone('America/Los_Angeles', 'PST', '-0800', 'PDT', '-0700'),
  'Alaska (AKT)': _Zone('America/Anchorage', 'AKST', '-0900', 'AKDT', '-0800'),
  'Hawaii (HT)': _Zone('Pacific/Honolulu', 'HST', '-1000'),
};

/// Builds an iCalendar (.ics) file that Apple Calendar, Google Calendar,
/// Samsung Calendar and Outlook can import.
class IcsBuilder {
  const IcsBuilder._();

  /// Length of a timed event, by kind. Due dates are short because the time
  /// marks a deadline, not a block of time.
  static Duration durationFor(EventType type) => switch (type) {
        EventType.exam => const Duration(hours: 1),
        _ => const Duration(minutes: 30),
      };

  /// [timeZoneLabel] is the label chosen on the upload screen. [now] is only
  /// for tests.
  static String build(
    List<ExtractedEvent> events, {
    required String timeZoneLabel,
    DateTime? now,
  }) {
    final zone = _zones[timeZoneLabel];
    final stamp = _utcStamp((now ?? DateTime.now()).toUtc());
    final lines = <String>[
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//Syllabus to Calendar//EN',
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
    ];

    final hasTimed = events.any((e) => parseClockTime(e.time) != null);
    if (zone != null && hasTimed) lines.addAll(zone.vtimezone);

    final usedIds = <String>{};
    for (final e in events) {
      lines.addAll(_event(e, zone, stamp, usedIds));
    }
    lines.add('END:VCALENDAR');

    return '${lines.expand(_fold).join('\r\n')}\r\n';
  }

  static List<String> _event(
    ExtractedEvent e,
    _Zone? zone,
    String stamp,
    Set<String> usedIds,
  ) {
    final clock = parseClockTime(e.time);
    final summary = e.course.trim().isEmpty ? e.title : '${e.course}: ${e.title}';

    final notes = <String>[
      if (e.course.trim().isNotEmpty) 'Course: ${e.course}',
      'Type: ${_typeLabel(e.type)}',
      if (e.time != null && e.time!.trim().isNotEmpty && clock == null)
        'Time in syllabus: ${e.time}',
      if (e.sourceQuote != null && e.sourceQuote!.trim().isNotEmpty)
        'From the syllabus: "${e.sourceQuote}"',
      'Added by Syllabus to Calendar',
    ];

    final when = <String>[];
    if (clock == null) {
      // All-day: DTEND is the day after, per the format.
      final day = DateTime.utc(e.date.year, e.date.month, e.date.day);
      when
        ..add('DTSTART;VALUE=DATE:${_date(day)}')
        ..add('DTEND;VALUE=DATE:${_date(day.add(const Duration(days: 1)))}');
    } else {
      // Plain UTC fields are used as a calendar, so the phone's own time zone
      // and daylight saving never shift the wall-clock time.
      final start = DateTime.utc(
        e.date.year,
        e.date.month,
        e.date.day,
        clock.hour,
        clock.minute,
      );
      final end = start.add(durationFor(e.type));
      final tz = zone == null ? '' : ';TZID=${zone.tzid}';
      when
        ..add('DTSTART$tz:${_wallClock(start)}')
        ..add('DTEND$tz:${_wallClock(end)}');
    }

    return [
      'BEGIN:VEVENT',
      'UID:${_uniqueId(e, usedIds)}',
      'DTSTAMP:$stamp',
      ...when,
      'SUMMARY:${_escape(summary)}',
      'DESCRIPTION:${_escape(notes.join('\n'))}',
      'CATEGORIES:${_escape(_typeLabel(e.type))}',
      // All-day items are reminders, not busy time.
      if (clock == null) 'TRANSP:TRANSPARENT',
      'END:VEVENT',
    ];
  }

  static String _typeLabel(EventType t) => switch (t) {
        EventType.exam => 'Exam',
        EventType.assignment => 'Assignment',
        EventType.reading => 'Reading',
        EventType.project => 'Project',
      };

  /// Same event, same ID, every time, so importing a file twice updates the
  /// events already in the calendar instead of duplicating them. The hash uses
  /// small numbers only, so it gives the same result on the web and on phones.
  static String _uniqueId(ExtractedEvent e, Set<String> used) {
    final key = '${e.course}|${e.title}|${e.type.name}|'
        '${_date(DateTime.utc(e.date.year, e.date.month, e.date.day))}|'
        '${e.time ?? ''}';
    var a = 7;
    var b = 11;
    for (final unit in key.codeUnits) {
      a = (a * 131 + unit) % 2147483647;
      b = (b * 137 + unit) % 2147483629;
    }
    final base = '${a.toRadixString(16).padLeft(8, '0')}'
        '${b.toRadixString(16).padLeft(8, '0')}';
    var id = base;
    for (var n = 2; !used.add(id); n++) {
      id = '$base-$n'; // two identical items in one file stay separate
    }
    return '$id@syllabus-to-calendar';
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _date(DateTime d) => '${d.year.toString().padLeft(4, '0')}'
      '${_two(d.month)}${_two(d.day)}';

  static String _wallClock(DateTime d) =>
      '${_date(d)}T${_two(d.hour)}${_two(d.minute)}00';

  static String _utcStamp(DateTime d) =>
      '${_date(d)}T${_two(d.hour)}${_two(d.minute)}${_two(d.second)}Z';

  /// Escapes text values as the format requires.
  static String _escape(String s) => s
      .replaceAll('\\', '\\\\')
      .replaceAll(';', '\\;')
      .replaceAll(',', '\\,')
      .replaceAll('\r\n', '\\n')
      .replaceAll('\n', '\\n')
      .replaceAll('\r', '\\n');

  /// Lines may be at most 75 bytes. Longer ones continue on the next line,
  /// which starts with a space. Splits fall between characters, never inside
  /// one, so accented letters and emoji survive.
  static List<String> _fold(String line) {
    final out = <String>[];
    var current = StringBuffer();
    var bytes = 0;
    for (final rune in line.runes) {
      final char = String.fromCharCode(rune);
      final size = utf8.encode(char).length;
      if (bytes + size > 75) {
        out.add(current.toString());
        current = StringBuffer(' ');
        bytes = 1;
      }
      current.write(char);
      bytes += size;
    }
    out.add(current.toString());
    return out;
  }
}
