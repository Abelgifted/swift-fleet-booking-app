// Live diagnostic probe: runs the REAL FleetService against the local proxy.
// Skips itself (rather than failing) when the proxy is not reachable, so it
// is safe to keep in the suite.
//
// Run with:
//   flutter test test/live_api_probe_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_booking/config/api_config.dart';
import 'package:fleet_booking/services/fleet_service.dart';

Future<bool> _proxyUp() async {
  try {
    final uri = Uri.parse('${ApiConfig.baseUrl}/trips/locations');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    final req = await client.getUrl(uri);
    req.headers.set('X-Api-Key', ApiConfig.apiKey);
    final res = await req.close();
    await res.drain<void>();
    client.close();
    return true;
  } catch (_) {
    return false;
  }
}

void main() {
  late bool up;

  setUpAll(() async {
    up = await _proxyUp();
    if (!up) {
      // ignore: avoid_print
      print('>>> PROXY DOWN at ${ApiConfig.baseUrl} — probe skipped');
    }
  });

  test('LIVE: locations parse into real places', () async {
    if (!up) return;
    final fleet = FleetService();
    final locations = await fleet.getLocations();
    // ignore: avoid_print
    print('>>> baseUrl = ${ApiConfig.baseUrl}');
    // ignore: avoid_print
    print('>>> locations (${locations.length}): '
        '${locations.map((l) => '${l.name}[${l.id}]').toList()}');
    expect(locations, isNotEmpty,
        reason: 'locations should parse from the API envelope');
    for (final l in locations) {
      expect(l.name.trim(), isNotEmpty,
          reason: 'parsed location must have a real name, got "$l"');
    }
  });

  test('LIVE: routes parse into real routes', () async {
    if (!up) return;
    final fleet = FleetService();
    final routes = await fleet.getRoutes();
    // ignore: avoid_print
    print('>>> routes (${routes.length}): '
        '${routes.map((r) => r.label).toList()}');
    expect(routes, isNotEmpty);
  });

  test('LIVE: a stale bearer token must not break the public catalog',
      () async {
    if (!up) return;
    final fleet = FleetService();

    // The upstream authenticates the store-scoped catalog with X-Api-Key +
    // apiKey/storeId and answers 401 when an unexpected Authorization header
    // is attached. Passing the logged-in user's token used to empty the
    // location list, which left the search button permanently disabled.
    // ApiService retries once without the token, so this must still work.
    final locations = await fleet.getLocations(authToken: 'stale-token');
    // ignore: avoid_print
    print('>>> getLocations(authToken: stale-token) -> ${locations.length} '
        'location(s)');
    expect(locations, isNotEmpty,
        reason: 'the retry-without-token path must recover the catalog');
  });

  test('LIVE: search returns trips or a clean empty result', () async {
    if (!up) return;
    final fleet = FleetService();
    final locations = await fleet.getLocations();
    if (locations.length < 2) return;
    final outcome = await fleet.searchTrips(
      sourceId: locations[0].id,
      sourceName: locations[0].name,
      destinationId: locations[1].id,
      destinationName: locations[1].name,
      date: DateTime.now().toIso8601String().substring(0, 10),
    );
    // ignore: avoid_print
    print('>>> search ${locations[0].name} -> ${locations[1].name} '
        'returned ${outcome.trips.length} trip(s) '
        'notice=${outcome.notice}');
    for (final t in outcome.trips) {
      // ignore: avoid_print
      print('    trip: id=${t.masterId} fare=${t.fare} '
          'from=${t.source} to=${t.destination}');
    }
  });
}
