import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

/// Tracks network reachability for the offline indicator + cache policy.
///
/// Production apps can expand this into retry queues; here it exposes a
/// simple [isOnline] flag + broadcast stream.
class ConnectivityService extends ChangeNotifier {
  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity() {
    _init();
  }

  Future<void> _init() async {
    try {
      _isOnline = await _checkOnline();
    } catch (_) {
      _isOnline = true;
    }
    notifyListeners();
    _sub = _connectivity.onConnectivityChanged.listen((results) {
      final online = results.any((r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet ||
          r == ConnectivityResult.vpn);
      if (online != _isOnline) {
        _isOnline = online;
        notifyListeners();
      }
    });
  }

  Future<bool> _checkOnline() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  /// Manual re-check (used by pull-to-refresh / retry buttons).
  Future<bool> refresh() async {
    try {
      _isOnline = await _checkOnline();
    } catch (_) {
      // Keep last known state.
    }
    notifyListeners();
    return _isOnline;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
