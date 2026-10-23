import 'dart:convert';
import 'dart:io';

import 'package:open_filex/open_filex.dart';

import 'ics_delivery_result.dart';

/// Writes the file to the app's temporary folder and asks the phone to open it
/// as a calendar file. Android shows the calendar apps that can take it, such
/// as Google Calendar or Samsung Calendar. On iPhone it opens the file preview,
/// which offers Calendar.
Future<IcsDeliveryResult> deliverIcs(String ics, String fileName) async {
  try {
    final dir = await Directory.systemTemp.createTemp('syllabus_');
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(ics, encoding: utf8);

    final result = await OpenFilex.open(
      file.path,
      type: 'text/calendar',
      uti: 'public.calendar-event',
    );
    return switch (result.type) {
      ResultType.done => IcsDeliveryResult.opened,
      ResultType.noAppToOpen => IcsDeliveryResult.noApp,
      _ => IcsDeliveryResult.failed,
    };
  } catch (_) {
    return IcsDeliveryResult.failed;
  }
}
