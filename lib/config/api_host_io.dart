import 'dart:io';

/// Native (dart:io) API host resolution.
///
/// - Android emulator reaches the host machine through the special
///   loopback alias `10.0.2.2` — `localhost` would hit the device itself.
/// - iOS simulators, desktop and tests share the host network, so plain
///   `localhost` works.
/// - A physical Android device is NOT covered by `10.0.2.2`; run with
///   `--dart-define=API_BASE_URL=http://<lan-ip>:8787/api/fleet`
///   (or set the `API_HOST` env var when launching from a desktop host).
String resolveApiHost() {
  final env = Platform.environment['API_HOST'];
  if (env != null && env.trim().isNotEmpty) {
    return env.trim();
  }
  if (Platform.isAndroid) {
    return 'http://10.0.2.2:8787';
  }
  return 'http://localhost:8787';
}
