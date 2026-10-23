// Opens a web page for the user. Only the browser build opens anything: on
// Android and iOS the calendar file already goes straight to a calendar app.
export 'open_page_stub.dart' if (dart.library.js_interop) 'open_page_web.dart';
