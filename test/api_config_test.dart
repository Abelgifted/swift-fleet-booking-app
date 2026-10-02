// Guards ApiConfig.resolveWebBaseUrl auto-detection.
//
// The Flutter web dev server (`flutter run -d chrome`) serves the bundle
// itself on a random localhost port, so same-origin `/api/*` 404s — the app
// must point at the local Node proxy on :8787 instead. On Render (or any
// non-loopback host) same-origin is correct.
import 'package:fleet_booking/config/api_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiConfig.resolveWebBaseUrl', () {
    test('Render / deployed origin stays same-origin', () {
      expect(
        ApiConfig.resolveWebBaseUrl(
          Uri.parse('https://swift-fleet-booking.onrender.com'),
        ),
        'https://swift-fleet-booking.onrender.com/api/fleet',
      );
    });

    test('preview URL stays same-origin', () {
      expect(
        ApiConfig.resolveWebBaseUrl(
          Uri.parse('https://swift-fleet-booking-pr-12.onrender.com/'),
        ),
        'https://swift-fleet-booking-pr-12.onrender.com/api/fleet',
      );
    });

    test('flutter dev server on localhost:<random> points at :8787 proxy', () {
      expect(
        ApiConfig.resolveWebBaseUrl(Uri.parse('http://localhost:54321/')),
        'http://localhost:8787/api/fleet',
      );
    });

    test('127.0.0.1 dev server points at :8787 proxy', () {
      expect(
        ApiConfig.resolveWebBaseUrl(Uri.parse('http://127.0.0.1:54174/')),
        'http://localhost:8787/api/fleet',
      );
    });

    test('page served by the proxy itself (:8787) stays same-origin', () {
      expect(
        ApiConfig.resolveWebBaseUrl(Uri.parse('http://localhost:8787/')),
        'http://localhost:8787/api/fleet',
      );
    });

    test('loopback without an explicit port uses the local proxy', () {
      expect(
        ApiConfig.resolveWebBaseUrl(Uri.parse('http://localhost')),
        'http://localhost:8787/api/fleet',
      );
    });
  });
}
