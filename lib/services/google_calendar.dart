import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../models/syllabus.dart';
import 'ics_builder.dart';

class CalendarSaveException implements Exception {
  const CalendarSaveException(this.message, {this.saved = 0});
  final String message;
  final int saved;
}

/// Uses a short-lived Google OAuth access token, never a Firebase ID token.
class GoogleCalendar {
  GoogleCalendar({required this.authorize, http.Client? client})
    : _client = client ?? http.Client();

  final Future<String> Function() authorize;
  final http.Client _client;
  String? _token;
  DateTime? _expires;

  Future<void> connect() async {
    _token = await authorize();
    _expires = DateTime.now().add(const Duration(minutes: 50));
  }

  Future<int> save(List<ExtractedEvent> events, String timeZone) async {
    // Validate everything before writing the first date.
    final bodies = events.map((e) => googleEvent(e, timeZone)).toList();
    if (_token == null || !_expires!.isAfter(DateTime.now())) await connect();
    var saved = 0;
    try {
      for (final body in bodies) {
        final response = await _client
            .post(
              Uri.https(
                'www.googleapis.com',
                '/calendar/v3/calendars/primary/events',
              ),
              headers: {
                'Authorization': 'Bearer $_token',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 30));
        // Stable IDs make retrying a partial upload safe.
        if (response.statusCode == 409 ||
            (response.statusCode >= 200 && response.statusCode < 300)) {
          saved++;
          continue;
        }
        if (response.statusCode == 401 || response.statusCode == 403) {
          _token = null;
          throw CalendarSaveException(
            response.statusCode == 401
                ? 'Calendar access expired. Try saving again to reconnect.'
                : 'Calendar access was denied. Grant calendar permission and check that the Google Calendar API is enabled.',
          );
        }
        throw const CalendarSaveException(
          'Google Calendar could not save the dates. Try again.',
        );
      }
    } on CalendarSaveException catch (error) {
      throw CalendarSaveException(error.message, saved: saved);
    } catch (_) {
      throw CalendarSaveException(
        'Check your connection and try again.',
        saved: saved,
      );
    }
    return saved;
  }

  void dispose() => _client.close();
}

Map<String, Object> googleEvent(ExtractedEvent event, String timeZone) {
  const zones = {
    'Eastern (ET)': 'America/New_York',
    'Central (CT)': 'America/Chicago',
    'Mountain (MT)': 'America/Denver',
    'Pacific (PT)': 'America/Los_Angeles',
    'Alaska (AKT)': 'America/Anchorage',
    'Hawaii (HT)': 'Pacific/Honolulu',
  };
  final clock = parseClockTime(event.time);
  final day = DateTime.utc(event.date.year, event.date.month, event.date.day);
  final Map<String, Object> start;
  final Map<String, Object> end;
  if (clock == null) {
    start = {'date': day.toIso8601String().substring(0, 10)};
    end = {
      'date': day
          .add(const Duration(days: 1))
          .toIso8601String()
          .substring(0, 10),
    };
  } else {
    final zone = zones[timeZone];
    if (zone == null) {
      throw const CalendarSaveException(
        'Choose a supported time zone before saving.',
      );
    }
    final time = day.add(Duration(hours: clock.hour, minutes: clock.minute));
    // Floating wall-clock times paired with IANA zones let Google apply DST.
    String wall(DateTime d) => d.toIso8601String().replaceFirst('Z', '');
    start = {'dateTime': wall(time), 'timeZone': zone};
    end = {
      'dateTime': wall(time.add(IcsBuilder.durationFor(event.type))),
      'timeZone': zone,
    };
  }
  final body = <String, Object>{
    'summary': event.course.trim().isEmpty
        ? event.title
        : '${event.course}: ${event.title}',
    'description': [
      'Added by Termwise',
      'Type: ${event.type.name}',
      if (event.sourceQuote != null) 'From the syllabus: ${event.sourceQuote}',
      if (clock == null && event.time != null)
        'Time in syllabus: ${event.time}',
    ].join('\n'),
    'start': start,
    'end': end,
  };
  // Content identity survives retries and re-extraction with different item IDs.
  body['id'] = sha256.convert(utf8.encode(jsonEncode(body))).toString();
  return body;
}
