// Gives the calendar file to the user: opens it in the phone's calendar app on
// Android and iOS, and downloads it in the browser on the web.
export 'ics_delivery_result.dart';
export 'ics_delivery_stub.dart'
    if (dart.library.js_interop) 'ics_delivery_web.dart'
    if (dart.library.io) 'ics_delivery_io.dart';
