import 'package:fetch_client/fetch_client.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

/// An HTTP client whose response body can be read as it arrives.
///
/// On the web, package:http's default client waits for the whole response,
/// which would make every progress stage appear at once at the end. The
/// fetch-based client streams instead.
http.Client streamingClient() =>
    kIsWeb ? FetchClient(mode: RequestMode.cors) : http.Client();
