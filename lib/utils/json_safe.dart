/// Defensive JSON field access for real-world API payloads.
///
/// Backends return nulls, strings where numbers are expected, doubles
/// where ints are expected, and wrapper objects around the actual data.
/// Every helper here degrades gracefully instead of throwing, so a bad
/// payload can never blank a screen.
class JsonSafe {
  JsonSafe._();

  /// Null-safe string: null → [fallback], any scalar → its toString,
  /// containers (Map/List) → [fallback] so a malformed payload can't
  /// leak debug text into the UI.
  static String asString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    if (value is String) return value;
    if (value is num || value is bool) return '$value';
    return fallback;
  }

  /// Null-safe double: accepts num and numeric strings; otherwise 0.
  static double toDouble(dynamic value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim()) ?? fallback;
    return fallback;
  }

  /// Null-safe int: accepts int, num (truncated) and numeric strings.
  static int toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final v = int.tryParse(value.trim()) ??
          double.tryParse(value.trim())?.toInt();
      return v ?? fallback;
    }
    return fallback;
  }

  /// Coerces any Map into `Map<String, dynamic>` (jsonDecode yields
  /// `Map<String, dynamic>` but hand-built caches may not).
  static Map<String, dynamic>? asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry('$k', v));
    }
    return null;
  }

  /// Finds the payload inside common API wrapper shapes:
  /// `{Data: …}`, `{data: …}`, `{Result: …}`, `{User: …}` etc.
  /// Returns the inner map, or the original map when nothing matches.
  static Map<String, dynamic> unwrap(Map<String, dynamic> json,
      [List<String> keys = const [
        'Data', 'data', 'Result', 'result', 'Payload', 'payload',
        'User', 'user', 'Customer', 'customer', 'Profile', 'profile',
      ]]) {
    for (final key in keys) {
      final inner = asMap(json[key]);
      if (inner != null) return inner;
    }
    return json;
  }

  /// Extracts a list under any of [keys] from a wrapper map.
  static List<dynamic>? listUnder(Map<String, dynamic> json,
      [List<String> keys = const [
        'items', 'Items', 'data', 'Data', 'result', 'Result',
        'results', 'Results', 'trips', 'Trips', 'locations', 'Locations',
        'routes', 'Routes', 'seats', 'Seats', 'bookings', 'Bookings',
      ]]) {
    for (final key in keys) {
      final v = json[key];
      if (v is List) return v;
    }
    return null;
  }
}
