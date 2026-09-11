import 'package:dio/dio.dart';

import 'package:fleet_booking/services/api_service.dart';

/// Offline stand-in for [ApiService] used by widget tests.
///
/// Serves canned payloads per endpoint path, or throws [ApiException]
/// for paths mapped to a [StubFailure], so screens can be exercised
/// without a live backend.
class StubApiService extends ApiService {
  /// path → JSON body (List or Map).
  final Map<String, Object?> responses;

  /// Paths that must fail instead of returning data.
  final Set<String> failurePaths;

  StubApiService({
    this.responses = const {},
    this.failurePaths = const {},
  });

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? queryParams,
    String? authToken,
    T Function(dynamic data)? fromJson,
  }) async =>
      _respond<T>(path);

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Object? body,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? queryParams,
    String? authToken,
    T Function(dynamic data)? fromJson,
  }) async =>
      _respond<T>(path);

  Response<T> _respond<T>(String path) {
    if (failurePaths.contains(path)) {
      throw const ApiException(
        'Network error. Please check your connection.',
      );
    }
    final body = responses[path];
    if (body == null) {
      throw const ApiException('Network error. Please check your connection.');
    }
    return Response<T>(
      data: body as T,
      requestOptions: RequestOptions(path: path),
    );
  }
}
