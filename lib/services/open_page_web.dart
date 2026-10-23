import 'package:web/web.dart' as web;

/// Opens [url] in a new tab. Call it while handling the user's tap, before
/// any await, or the browser may block it as a popup. Returns true when the
/// tab was requested without an error.
bool openPageInNewTab(String url) {
  try {
    web.window.open(url, '_blank', 'noopener');
    return true;
  } catch (_) {
    return false;
  }
}
