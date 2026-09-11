/// Web (and default) API host resolution.
///
/// Selected automatically by the conditional import in `api_config.dart` when
/// `dart:io` is unavailable.
///
/// Note: on web [ApiConfig] normally uses the **page's own origin** instead of
/// this value, because the Node service in `swift-fleet-api/` serves the app
/// and proxies `/api/*` together. This host is only the fallback for a web
/// build that is served by something other than that service (for example
/// `flutter run -d chrome`, which serves the bundle itself).
String resolveApiHost() => 'http://localhost:8787';
