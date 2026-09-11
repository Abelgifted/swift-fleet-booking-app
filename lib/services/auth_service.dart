import '../models/user.dart';
import '../config/api_config.dart';
import '../utils/constants.dart';
import '../utils/json_safe.dart';
import 'api_service.dart';

/// Thin wrapper around the fleet auth endpoints.
///
/// Canonical routes are `/auth/*`; legacy `/login` & `/register` are
/// tried automatically as a fallback so the app works against either
/// backend version.
class AuthService {
  final ApiService _api;

  AuthService({ApiService? api}) : _api = api ?? ApiService();

  /// POST login → [User]. Tries `/auth/login`, falls back to `/login`.
  Future<User> login({required String email, required String password}) {
    return _postUser(
      primary: AppConstants.epAuthLogin,
      fallback: AppConstants.epLogin,
      body: {'Email': email, 'email': email, 'Password': password, 'password': password},
    );
  }

  /// POST register → [User]. Tries `/auth/register`, falls back to `/register`.
  Future<User> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) {
    return _postUser(
      primary: AppConstants.epAuthRegister,
      fallback: AppConstants.epRegister,
      body: {
        'apiKey': ApiConfig.apiKey,
        'storeId': ApiConfig.storeId,
        'customerName': name,
        'email': email,
        'phone': phone,
        'password': password,
      },
    );
  }

  /// POST logout (best-effort — never throws).
  Future<void> logout({String? authToken}) async {
    for (final path in [AppConstants.epAuthLogout, AppConstants.epLogout]) {
      try {
        await _api.post(path, body: const {}, authToken: authToken);
        return;
      } on ApiException {
        continue; // try the fallback route
      }
    }
  }

  /// GET profile → [User]. Tries `/auth/profile`, falls back to `/profile`.
  Future<User> getProfile({String? authToken}) async {
    ApiException? lastError;
    for (final path in [AppConstants.epAuthProfile, AppConstants.epProfile]) {
      try {
        final res = await _api.post<Map<String, dynamic>>(
          path,
          body: const {},
          authToken: authToken,
          fromJson: _asUserMap,
        );
        // Some backends return profile via GET instead — handled below.
        if (res.data != null) return User.fromJson(res.data!);
      } on ApiException catch (e) {
        lastError = e;
      }
    }
    // Final attempt via GET (some APIs expose profile as GET).
    try {
      final res = await _api.get<Map<String, dynamic>>(
        AppConstants.epAuthProfile,
        authToken: authToken,
        fromJson: _asUserMap,
      );
      if (res.data != null) return User.fromJson(res.data!);
    } on ApiException catch (e) {
      lastError = e;
    }
    throw lastError ?? const ApiException('Unable to load profile');
  }

  /// PUT profile → updated [User].
  Future<User> updateProfile({
    required String authToken,
    String? name,
    String? phone,
  }) async {
    final body = <String, dynamic>{
      if (name != null) ...{'CustomerName': name, 'customerName': name},
      if (phone != null) ...{'Phone': phone, 'phone': phone},
    };
    ApiException? lastError;
    for (final path in [AppConstants.epAuthProfile, AppConstants.epProfile]) {
      try {
        final res = await _api.put<Map<String, dynamic>>(
          path,
          body: body,
          authToken: authToken,
          fromJson: _asUserMap,
        );
        if (res.data != null) return User.fromJson(res.data!);
      } on ApiException catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? const ApiException('Unable to update profile');
  }

  /// Normalizes real-world auth payloads: unwraps `{Data: {…}}` /
  /// `{User: {…}}` shapes and lifts a top-level token into the map.
  /// Exposed for tests + [User.fromJson] parity.
  static Map<String, dynamic> extractUserMap(dynamic raw) {
    final map = JsonSafe.asMap(raw);
    if (map == null) return const {};
    final inner = JsonSafe.unwrap(map);
    final token = JsonSafe.asString(map['Token'] ?? map['token']);
    if (token.isNotEmpty) {
      return {...inner, 'Token': token};
    }
    return inner;
  }

  /// Strict map coercion for response bodies: a non-map payload becomes
  /// a friendly [ApiException] instead of a raw TypeError.
  static Map<String, dynamic> _asUserMap(dynamic json) {
    final map = JsonSafe.asMap(json);
    if (map == null) {
      throw const ApiException('Unexpected response from server');
    }
    return map;
  }

  // ── Internal ──────────────────────────────────────────────────

  Future<User> _postUser({
    required String primary,
    required String fallback,
    required Map<String, dynamic> body,
  }) async {
    ApiException? lastError;
    for (final path in [primary, fallback]) {
      try {
        final res = await _api.post<Map<String, dynamic>>(
          path,
          body: body,
          fromJson: _asUserMap,
        );
        if (res.data == null) {
          throw const ApiException('Empty response from server');
        }
        return User.fromJson(extractUserMap(res.data!));
      } on ApiException catch (e) {
        lastError = e;
        // 404 on the canonical route → try the legacy fallback.
        // Any other error (wrong password etc.) → surface immediately.
        if (e.statusCode != null && e.statusCode != 404) rethrow;
      }
    }
    throw lastError ?? const ApiException('Authentication failed');
  }
}
