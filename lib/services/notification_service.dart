import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/constants.dart';

/// Push/local notification facade.
///
/// Phase 6 ships a production-shaped placeholder: permission request,
/// topic subscription stubs, and an in-app inbox so booking events
/// (confirmations, reminders) are visible without a push backend.
/// Wiring Firebase Cloud Messaging later only touches this file.
class AppNotification {
  final String id;
  final String title;
  final String body;
  final String receivedAt;
  bool read;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.receivedAt,
    this.read = false,
  });
}

class NotificationService extends ChangeNotifier {
  bool _enabled = true;
  bool _permissionGranted = false;
  final List<AppNotification> _inbox = [];

  bool get enabled => _enabled;
  bool get permissionGranted => _permissionGranted;
  List<AppNotification> get inbox => List.unmodifiable(_inbox);
  int get unreadCount => _inbox.where((n) => !n.read).length;

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled =
          prefs.getBool(AppConstants.keyNotifications) ?? true;
    } catch (_) {
      // Defaults stand.
    }
    notifyListeners();
  }

  /// Requests OS notification permission.
  ///
  /// TODO(prod): replace with firebase_messaging
  /// `requestPermission()` + permission_handler fallback.
  Future<bool> requestPermission() async {
    _permissionGranted = true; // in-app inbox always available
    notifyListeners();
    return true;
  }

  Future<void> setEnabled(bool v) async {
    _enabled = v;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.keyNotifications, v);
    } catch (_) {
      // Best-effort.
    }
  }

  /// Queues an in-app notification (e.g. booking confirmed).
  void push(String title, String body) {
    if (!_enabled) return;
    _inbox.insert(
      0,
      AppNotification(
        id: 'ntf-${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        body: body,
        receivedAt: DateTime.now().toIso8601String(),
      ),
    );
    notifyListeners();
  }

  void markAllRead() {
    for (final n in _inbox) {
      n.read = true;
    }
    notifyListeners();
  }

  void clear() {
    _inbox.clear();
    notifyListeners();
  }
}
