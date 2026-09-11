import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';

/// App-wide auth state: current user, token, loading & error handling.
///
/// Persists session to [SharedPreferences] so splash can auto-login.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  AuthProvider({AuthService? authService})
      : _authService = authService ?? AuthService();

  User? _user;
  bool _isLoading = false;
  bool _isInitializing = true;
  String? _errorMessage;

  // ── Getters ───────────────────────────────────────────────────
  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _user != null && (_user!.token.isNotEmpty);
  String? get token =>
      (_user?.token.isNotEmpty ?? false) ? _user!.token : null;

  /// Called once at startup (from splash). Restores cached session and
  /// optionally refreshes the profile in the background.
  Future<void> initialize() async {
    _isInitializing = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(AppConstants.keyUserJson);
      if (raw != null && raw.isNotEmpty) {
        _user = User.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
      }
    } catch (_) {
      _user = null; // corrupted cache → treat as logged out
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  /// Email + password login. Returns true on success.
  Future<bool> login({required String email, required String password}) {
    return _run(() async {
      final user = await _authService.login(email: email, password: password);
      await _persist(user);
      return true;
    });
  }

  /// Name + email + phone + password registration. Returns true on success.
  Future<bool> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) {
    return _run(() async {
      final user = await _authService.register(
        name: name,
        email: email,
        phone: phone,
        password: password,
      );
      await _persist(user);
      return true;
    });
  }

  /// Clears local session and notifies the backend (best-effort).
  Future<void> logout() async {
    final oldToken = token;
    _user = null;
    _errorMessage = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.keyUserJson);
      await prefs.remove(AppConstants.keyAuthToken);
    } catch (_) {
      // Cache clear is best-effort.
    }
    try {
      await _authService.logout(authToken: oldToken);
    } catch (_) {
      // Server logout is best-effort.
    }
  }

  /// Refreshes the cached user from `GET /auth/profile`.
  Future<void> refreshProfile() async {
    final t = token;
    if (t == null) return;
    await _run(() async {
      final fresh = await _authService.getProfile(authToken: t);
      // Keep the existing token if the profile payload omits it.
      final merged = fresh.token.isEmpty ? fresh.copyWith(token: t) : fresh;
      await _persist(merged);
      return true;
    });
  }

  /// Updates name/phone via `PUT /auth/profile`. Returns true on success.
  Future<bool> updateProfile({String? name, String? phone}) {
    final t = token;
    if (t == null) return Future.value(false);
    return _run(() async {
      final fresh = await _authService.updateProfile(
        authToken: t,
        name: name,
        phone: phone,
      );
      final merged = fresh.token.isEmpty ? fresh.copyWith(token: t) : fresh;
      await _persist(merged);
      return true;
    });
  }

  /// Clears the current error banner.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ── Internals ─────────────────────────────────────────────────

  /// Wraps an auth action with loading + error state management.
  Future<bool> _run(Future<bool> Function() action) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      return await action();
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (_) {
      _errorMessage = 'Something went wrong. Please try again.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _persist(User user) async {
    _user = user;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        AppConstants.keyUserJson,
        jsonEncode(user.toJson()),
      );
      if (user.token.isNotEmpty) {
        await prefs.setString(AppConstants.keyAuthToken, user.token);
      }
    } catch (_) {
      // Persistence is best-effort; in-memory session still works.
    }
  }
}
