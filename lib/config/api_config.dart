import 'package:flutter/foundation.dart' show kIsWeb;

import 'api_host_default.dart'
    if (dart.library.io) 'api_host_io.dart';

/// Central API configuration.
///
/// Base URL resolution order:
/// 1. `--dart-define=API_BASE_URL=https://…/api/fleet` (explicit override —
///    use this for a sub-path deployment or a remote backend).
/// 2. **Web** → auto-detected from the page's own origin ([Uri.base]):
///    - Render / preview / any non-loopback host → same origin, i.e.
///      `${Uri.base.origin}/api/fleet`. The Node service in
///      `swift-fleet-api/` hosts the compiled Flutter bundle *and* proxies
///      `/api/*` on the same origin, so this needs no CORS preflight.
///    - Local dev (`flutter run -d chrome`, which serves the bundle itself on
///      e.g. `http://localhost:54321`) → `http://localhost:8787/api/fleet`,
///      where the local Node proxy runs. Detected when the page host is
///      `localhost`/`127.0.0.1` with a port other than 8787.
/// 3. **Native** → auto-detected per platform:
///    - Android (emulator) → http://10.0.2.2:8787/api/fleet
///    - iOS sim / desktop  → http://localhost:8787/api/fleet
///
/// Resolution is computed on every access, so on web it reads the current
/// page location.
class ApiConfig {
  /// Path segment the fleet API lives under, on every host.
  static const String apiPath = '/api/fleet';

  // Compile-time override wins over auto-detection when provided.
  static const String _dartDefineBaseUrl =
      String.fromEnvironment('API_BASE_URL');

  /// Resolved base URL for the current platform (getter so web reads
  /// [Uri.base] fresh each time instead of caching the dev-server origin).
  static String get baseUrl => _resolveBaseUrl();

  /// Store API key.
  ///
  /// The Node proxy injects its own `API_KEY` server-side and overwrites the
  /// `apiKey` query parameter, so this value is only a local-development
  /// fallback — rotating the key on the server does not require a rebuild.
  static const String apiKey = 'SK_live_e5a57f63ebff4fdb822efc23';

  /// Store identifier every store-scoped endpoint is filtered by.
  static const String storeId = 'bentalsupermarket';

  // ---------------------------------------------------------------------------
  // Trip search defaults
  // ---------------------------------------------------------------------------

  /// Origin terminal for trip searches — the location **Name** (e.g.
  /// `Abuja`), never the GUID Id. The upstream resolves routes by name.
  static const String source = 'abuja';

  /// Destination terminal for trip searches — the location **Name** (e.g.
  /// `Jos`), never the GUID Id.
  static const String destination = 'jos';

  /// Travel date for trip searches, as `yyyy-MM-dd`.
  ///
  /// Kept as a compile-time default so a plain `flutter run` hits a valid
  /// date; callers that need another day should pass their own value to
  /// [addDefaultQueryParams] / [getTripQueryParams].
  static const String date = '2026-09-29';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);

  // Content type
  static const String contentTypeJson = 'application/json';

  /// Header the backend expects the API key in.
  static const String apiKeyHeader = 'x-api-key';

  /// True when the app talks to the proxy on its own origin. The diagnostics
  /// screen uses this to explain that no host was hardcoded.
  static bool get isSameOrigin =>
      !kIsWeb || baseUrl.startsWith(Uri.base.origin);

  static String _resolveBaseUrl() {
    if (_dartDefineBaseUrl.isNotEmpty) return _normalize(_dartDefineBaseUrl);
    if (kIsWeb) {
      return resolveWebBaseUrl(Uri.base);
    }
    return '${resolveApiHost()}$apiPath';
  }

  /// Picks the web base URL from the page's own [origin].
  ///
  /// Public (and `@visibleForTesting`-free on purpose — plain static helpers
  /// keep `flutter test` able to cover this without a browser) so the
  /// detection rules are unit-testable:
  /// - loopback host (`localhost`/`127.0.0.1`) with a port other than 8787 →
  ///   the Flutter dev server is serving the bundle, so point at the local
  ///   Node proxy on `http://localhost:8787`.
  /// - anything else (Render, preview URL, or the proxy itself on :8787) →
  ///   same origin, which serves the bundle *and* proxies `/api/*`.
  static String resolveWebBaseUrl(Uri origin) {
    if (_isLoopback(origin) && origin.port != _localProxyPort) {
      return 'http://localhost:$_localProxyPort$apiPath';
    }
    return '${origin.origin}$apiPath';
  }

  /// Port the local Node proxy (`swift-fleet-api/server.js`) listens on.
  static const int _localProxyPort = 8787;

  static bool _isLoopback(Uri uri) =>
      uri.host == 'localhost' || uri.host == '127.0.0.1';

  /// Strips a trailing slash so endpoint concatenation stays predictable.
  static String _normalize(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  // ---------------------------------------------------------------------------
  // Headers
  // ---------------------------------------------------------------------------

  /// Get headers for API requests.
  ///
  /// The API key travels in the `x-api-key` header (lower-case, matching the
  /// gateway's expectation). `authToken`, when supplied, is added as a bearer
  /// token for user-scoped endpoints.
  static Map<String, String> getHeaders({String? authToken}) {
    return {
      apiKeyHeader: apiKey,
      'Content-Type': contentTypeJson,
      'Accept': contentTypeJson,
      if (authToken != null) 'Authorization': 'Bearer $authToken',
    };
  }

  static Map<String, dynamic> get dioHeaders => getHeaders();

  // ---------------------------------------------------------------------------
  // Query parameters
  // ---------------------------------------------------------------------------

  /// Get query parameters for store-scoped endpoints.
  static Map<String, String> getQueryParams() {
    return {
      'apiKey': apiKey,
      'storeId': storeId,
      'source': source,
      'destination': destination,
      'date': date,
    };
  }

  /// Get query parameters for a trip search, allowing any of the trip
  /// dimensions to be overridden per request.
  static Map<String, String> getTripQueryParams({
    String? storeId,
    String? source,
    String? destination,
    String? date,
  }) {
    return {
      'apiKey': apiKey,
      'storeId': storeId ?? ApiConfig.storeId,
      'source': source ?? ApiConfig.source,
      'destination': destination ?? ApiConfig.destination,
      'date': date ?? ApiConfig.date,
    };
  }

  /// Add default query params to a map.
  ///
  /// [additionalParams] wins over the defaults, so a caller can override
  /// `source`, `destination`, `date`, etc. for a single request.
  static Map<String, dynamic> addDefaultQueryParams([
    Map<String, dynamic>? additionalParams,
  ]) {
    return {
      ...getQueryParams(),
      ...?additionalParams,
    };
  }
}