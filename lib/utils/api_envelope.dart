import 'json_safe.dart';

/// Parsing for the fleet API's response envelope.
///
/// Every collection endpoint answers with the same wrapper:
///
/// ```json
/// { "Success": true, "Message": "Locations retrieved",
///   "Data": { "Locations": [ … ] }, "StatusCode": 200 }
/// ```
///
/// The `Data` value is *sometimes* the list itself (routes) and sometimes a
/// map that merely contains one (locations, trips). Both shapes have to work,
/// and the envelope must never be mistaken for a single row — that mistake
/// silently produced one garbage record instead of the real collection.
class ApiEnvelope {
  ApiEnvelope._();

  /// Keys that hold the actual payload inside the envelope.
  static const List<String> _payloadKeys = [
    'Data', 'data', 'Result', 'result', 'Payload', 'payload',
  ];

  /// Extracts the payload list from a decoded response body.
  static List<dynamic> listFrom(dynamic body) {
    if (body is List) return body;
    final map = JsonSafe.asMap(body);
    if (map == null) return const [];

    // 1. Unwrap the standard envelope and look inside it.
    for (final key in _payloadKeys) {
      if (!map.containsKey(key)) continue;
      final found = findList(map[key]);
      if (found != null) return found;
    }

    // 2. Known wrapper keys directly on the body.
    final under = JsonSafe.listUnder(map);
    if (under != null) return under;

    // 3. Any list-valued field (e.g. {Locations: [...]}).
    final any = findList(map);
    if (any != null) return any;

    // 4. Looks like an envelope but carries no collection
    //    (`Data: null`, e.g. a 404 "Trip not found") → genuinely no rows.
    //    Without this the envelope would be mistaken for one row.
    if (map.containsKey('Data') || map.containsKey('data')) return const [];

    // 5. Single-object response → treat the body itself as one row.
    return [map];
  }

  /// The server's human-readable message, when present.
  static String? messageFrom(dynamic body) {
    final map = JsonSafe.asMap(body);
    if (map == null) return null;
    final raw = map['Message'] ?? map['message'];
    if (raw is! String) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// True when the body carries an explicit `Success: false`.
  static bool isFailure(dynamic body) {
    final map = JsonSafe.asMap(body);
    if (map == null) return false;
    final v = map['Success'] ?? map['success'];
    return v == false;
  }

  /// Finds a list inside [node], unwrapping one level of map if needed.
  static List<dynamic>? findList(dynamic node) {
    if (node is List) return node;
    final map = JsonSafe.asMap(node);
    if (map == null) return null;
    final under = JsonSafe.listUnder(map);
    if (under != null) return under;
    for (final v in map.values) {
      if (v is List) return v;
    }
    return null;
  }

  /// Convenience: both halves of the envelope in one call.
  static ({List<dynamic> items, String? message}) parse(dynamic body) =>
      (items: listFrom(body), message: messageFrom(body));
}
