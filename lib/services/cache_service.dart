import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/constants.dart';

/// TTL JSON cache for catalog data (locations / routes / last search).
///
/// Strategy: network-first, cache-fallback. On success the payload is
/// stored; on failure the last fresh-enough entry is returned so the app
/// stays usable offline.
class CacheService {
  /// Writes [jsonEncodable] under [key] with a timestamp.
  static Future<void> put(String key, Object jsonEncodable) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        key,
        jsonEncode({
          'at': DateTime.now().toIso8601String(),
          'data': jsonEncodable,
        }),
      );
      await prefs.setString(
        '${AppConstants.keyCacheTime}_$key',
        DateTime.now().toIso8601String(),
      );
    } catch (_) {
      // Cache is best-effort.
    }
  }

  /// Reads a cached entry, or null when missing/corrupt/expired.
  static Future<dynamic> get(String key,
      {Duration ttl = AppConstants.cacheTtl}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final at = DateTime.tryParse('${decoded['at']}');
      if (at == null || DateTime.now().difference(at) > ttl) {
        return null;
      }
      return decoded['data'];
    } catch (_) {
      return null;
    }
  }

  /// Reads regardless of age (last-resort offline fallback).
  static Future<dynamic> getStale(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;
      return (jsonDecode(raw) as Map<String, dynamic>)['data'];
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.keyCacheLocations);
      await prefs.remove(AppConstants.keyCacheRoutes);
      await prefs.remove(AppConstants.keyCacheTrips);
    } catch (_) {
      // Best-effort.
    }
  }
}

/// Slim offline banner shown at the top of key screens.
class OfflineBar extends StatelessWidget {
  const OfflineBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.orange.shade800,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded,
              size: 16, color: Colors.white),
          SizedBox(width: 8),
          Text(
            'Offline — showing cached data',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
