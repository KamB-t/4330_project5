import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'ics_delivery_result.dart';

/// Downloads the file through the browser.
Future<IcsDeliveryResult> deliverIcs(String ics, String fileName) async {
  try {
    final bytes = Uint8List.fromList(utf8.encode(ics));
    final blob = web.Blob(
      <JSAny>[bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'text/calendar'),
    );
    final url = web.URL.createObjectURL(blob);
    final link = web.HTMLAnchorElement()
      ..href = url
      ..download = fileName;
    web.document.body!.append(link);
    link.click();
    link.remove();
    web.URL.revokeObjectURL(url);
    return IcsDeliveryResult.downloaded;
  } catch (_) {
    return IcsDeliveryResult.failed;
  }
}
