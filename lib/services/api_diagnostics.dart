import 'dart:convert';

import '../utils/constants.dart';
import 'api_service.dart';
import 'fleet_service.dart';

/// Outcome of probing a single endpoint.
class EndpointProbe {
  final String label;
  final String path;
  final String url;
  final bool ok;
  final int? statusCode;
  final int durationMs;

  /// Pretty-printed response body, or the error text on failure.
  final String body;

  /// Non-null when the probe failed.
  final String? error;

  /// How many rows the payload contained, when countable.
  final int? rowCount;

  const EndpointProbe({
    required this.label,
    required this.path,
    required this.url,
    required this.ok,
    required this.statusCode,
    required this.durationMs,
    required this.body,
    this.error,
    this.rowCount,
  });

  /// True when the endpoint answered but returned nothing — worth calling
  /// out separately from a hard failure.
  bool get isUnexpectedlyEmpty => ok && rowCount == 0;
}

/// Runs a health check across the fleet endpoints so the app can show
/// exactly what the backend is returning.
class ApiDiagnostics {
  ApiDiagnostics._();

  static String get baseUrl => ApiService.resolvedBaseUrl;

  /// Probes locations, routes and a representative trip search.
  static Future<List<EndpointProbe>> runAll() async {
    final probes = <EndpointProbe>[];

    final locations = await _probe(
      label: 'Locations',
      path: AppConstants.epTripsLocations,
      countRows: _countList,
    );
    probes.add(locations);

    final routes = await _probe(
      label: 'Routes',
      path: AppConstants.epTripsRoutes,
      countRows: _countList,
    );
    probes.add(routes);

    // Pick a real origin/destination pair for the search probe.
    final places = await _safeLocations();
    final hasPair = places.length >= 2;
    final from = hasPair ? places[0] : null;
    final to = hasPair ? places[1] : null;

    probes.add(await _probe(
      label: hasPair
          ? 'Trip search (${from!.name.trim()} → ${to!.name.trim()})'
          : 'Trip search',
      path: AppConstants.epTripsSearch,
      query: {
        if (from != null) 'source': from.id,
        if (to != null) 'destination': to.id,
        'date': DateTime.now().toIso8601String().substring(0, 10),
      },
      countRows: _countTrips,
    ));

    return probes;
  }

  static Future<List<dynamic>> _safeLocations() async {
    try {
      return await FleetService().getLocations();
    } catch (_) {
      return const [];
    }
  }

  static Future<EndpointProbe> _probe({
    required String label,
    required String path,
    Map<String, dynamic>? query,
    required int? Function(dynamic body) countRows,
  }) async {
    final api = ApiService();
    final started = DateTime.now();
    try {
      final res = await api.get<dynamic>(path, queryParameters: query);
      final ms = DateTime.now().difference(started).inMilliseconds;
      final url = res.requestOptions.uri.toString();
      return EndpointProbe(
        label: label,
        path: path,
        url: url,
        ok: true,
        statusCode: res.statusCode,
        durationMs: ms,
        body: _pretty(res.data),
        rowCount: countRows(res.data),
      );
    } on ApiException catch (e) {
      final ms = DateTime.now().difference(started).inMilliseconds;
      return EndpointProbe(
        label: label,
        path: path,
        url: e.url ?? '${ApiService.resolvedBaseUrl}$path',
        ok: false,
        statusCode: e.statusCode,
        durationMs: ms,
        body: _pretty(e.data),
        error: e.message,
      );
    } catch (e) {
      final ms = DateTime.now().difference(started).inMilliseconds;
      return EndpointProbe(
        label: label,
        path: path,
        url: '${ApiService.resolvedBaseUrl}$path',
        ok: false,
        statusCode: null,
        durationMs: ms,
        body: '$e',
        error: '$e',
      );
    }
  }

  // ── Row counting ────────────────────────────────────────────────

  static int? _countList(dynamic body) {
    final list = _deepList(body);
    return list?.length;
  }

  static int? _countTrips(dynamic body) {
    final map = body is Map ? body : null;
    if (map == null) return _countList(body);
    final data = map['Data'] ?? map['data'];
    final inner = data is Map ? data : map;
    final trips = inner['Trips'] ?? inner['trips'];
    if (trips is List) return trips.length;
    return _countList(body);
  }

  /// Finds the primary list in a `{Data:{Locations:[…]}}` style envelope.
  static List<dynamic>? _deepList(dynamic body) {
    if (body is List) return body;
    if (body is! Map) return null;
    for (final key in const ['Data', 'data', 'Result', 'result']) {
      final inner = body[key];
      if (inner is List) return inner;
      if (inner is Map) {
        for (final v in inner.values) {
          if (v is List) return v;
        }
      }
    }
    for (final v in body.values) {
      if (v is List) return v;
    }
    return null;
  }

  static String _pretty(dynamic body) {
    if (body == null) return '(empty response body)';
    if (body is String) return body;
    try {
      return const JsonEncoder.withIndent('  ').convert(body);
    } catch (_) {
      return '$body';
    }
  }
}
