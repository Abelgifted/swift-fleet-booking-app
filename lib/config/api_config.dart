import 'package:flutter/foundation.dart' show kIsWeb;

import 'api_host_default.dart'
    if (dart.library.io) 'api_host_io.dart';

/// Central API configuration.
///
/// Base URL resolution order:
/// 1. `--dart-define=API_BASE_URL=https://…/api/fleet` (explicit override —
///    use this for a sub-path deployment or a remote backend).
/// 2. **Web** → the page's own origin, i.e. `/api/fleet` on whatever domain
///    the app is served from. The Node service in `swift-fleet-api/` hosts the
///    compiled Flutter bundle *and* proxies `/api/*` on the same origin, so
///    this works unchanged on Render, on a preview URL and on localhost.
/// 3. **Native** → auto-detected per platform:
///    - Android (emulator) → http://10.0.2.2:8787/api/fleet
///    - iOS sim / desktop  → http://localhost:8787/api/fleet
///
/// Resolution is lazy (`static final`), so on web it reads the location only
/// after the page has loaded.
class ApiConfig {
  /// Path segment the fleet API lives under, on every host.
  static const String apiPath = '/api/fleet';

  // Compile-time override wins over auto-detection when provided.
  static const String _dartDefineBaseUrl =
      String.fromEnvironment('API_BASE_URL');

  /// Resolved base URL for the current platform.
  static final String baseUrl = _resolveBaseUrl();

  /// Store API key.
  ///
  /// The Node proxy injects its own `API_KEY` server-side and overwrites the
  /// `apiKey` query parameter, so this value is only a local-development
  /// fallback — rotating the key on the server does not require a rebuild.
  static const String apiKey = 'SK_live_e5a57f63ebff4fdb822efc23';
  static const String storeId = 'bentalsupermarket';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);

  // Content type
  static const String contentTypeJson = 'application/json';

  /// True when the app talks to the proxy on its own origin. The diagnostics
  /// screen uses this to explain that no host was hardcoded.
  static bool get isSameOrigin =>
      !kIsWeb || baseUrl.startsWith(Uri.base.origin);

  static String _resolveBaseUrl() {
    if (_dartDefineBaseUrl.isNotEmpty) return _normalize(_dartDefineBaseUrl);
    if (kIsWeb) {
      // Same origin as the page — the server that serves this bundle also
      // proxies /api/*, so nothing is hardcoded and no CORS preflight is
      // needed.
      return '${Uri.base.origin}$apiPath';
    }
    return '${resolveApiHost()}$apiPath';
  }

  /// Strips a trailing slash so endpoint concatenation stays predictable.
  static String _normalize(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  // Get headers for API requests
  static Map<String, String> getHeaders({String? authToken}) {
    return {
      'X-Api-Key': apiKey,
      'Content-Type': contentTypeJson,
      'Accept': contentTypeJson,
      if (authToken != null) 'Authorization': 'Bearer $authToken',
    };
  }

  static Map<String, dynamic> get dioHeaders => getHeaders();

  // Get query parameters for store-scoped endpoints
  static Map<String, String> getQueryParams() {
    return {
      'apiKey': apiKey,
      'storeId': storeId,
    };
  }

  // Add default query params to a map
  static Map<String, dynamic> addDefaultQueryParams([
    Map<String, dynamic>? additionalParams,
  ]) {
    return {
      ...getQueryParams(),
      ...?additionalParams,
    };
  }
}
