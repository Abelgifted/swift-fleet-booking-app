import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_config.dart';

/// A single traced HTTP exchange, kept in memory so the diagnostics
/// screen can show the raw traffic without a separate log file.
class ApiLogEntry {
  final String method;
  final String url;
  final int? statusCode;
  final int durationMs;
  final bool ok;
  final String detail;

  const ApiLogEntry({
    required this.method,
    required this.url,
    required this.statusCode,
    required this.durationMs,
    required this.ok,
    required this.detail,
  });

  String get headline =>
      '$method ${statusCode ?? '---'} ${durationMs}ms  $url';
}

/// Thin Dio wrapper.
///
/// The important contract: every request is executed **untyped** and the
/// caller's `fromJson` transform is applied to the decoded body before the
/// result is handed back. Fleet endpoints wrap their payload in
/// `{Success, Message, Data:{…}}`, so asking Dio for a `List` directly would
/// fail to cast and surface as a bogus "network error".
class ApiService {
  final Dio _dio;
  String? _authToken;

  /// When true, every exchange is printed with [debugPrint] and recorded in
  /// [log]. Defaults to on in debug builds.
  static bool debugLogging = kDebugMode;

  /// Newest-first ring buffer of recent exchanges (diagnostics screen).
  static final List<ApiLogEntry> log = <ApiLogEntry>[];
  static const int _maxLogEntries = 80;

  ApiService() : _dio = Dio(BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          connectTimeout: ApiConfig.connectTimeout,
          receiveTimeout: ApiConfig.receiveTimeout,
          contentType: ApiConfig.contentTypeJson,
          responseType: ResponseType.json,
          headers: ApiConfig.dioHeaders,
        )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        options.headers.addAll(ApiConfig.getHeaders(authToken: _authToken));
        options.queryParameters = ApiConfig.addDefaultQueryParams(
          options.queryParameters,
        );
        handler.next(options);
      },
      onError: (error, handler) => handler.next(error),
    ));
  }

  /// Base URL currently in use — shown by the diagnostics screen.
  static String get resolvedBaseUrl => ApiConfig.baseUrl;

  void setAuthToken(String? token) {
    _authToken = token;
  }

  // ── Public verbs ────────────────────────────────────────────────

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? queryParams,
    String? authToken,
    T Function(dynamic data)? fromJson,
  }) =>
      _send<T>(
        method: 'GET',
        path: path,
        query: queryParameters ?? queryParams,
        authToken: authToken,
        transform: fromJson,
      );

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Object? body,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? queryParams,
    String? authToken,
    T Function(dynamic data)? fromJson,
  }) =>
      _send<T>(
        method: 'POST',
        path: path,
        data: data ?? body,
        query: queryParameters ?? queryParams,
        authToken: authToken,
        transform: fromJson,
      );

  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Object? body,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? queryParams,
    String? authToken,
    T Function(dynamic data)? fromJson,
  }) =>
      _send<T>(
        method: 'PUT',
        path: path,
        data: data ?? body,
        query: queryParameters ?? queryParams,
        authToken: authToken,
        transform: fromJson,
      );

  Future<Response<T>> delete<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? queryParams,
    String? authToken,
    T Function(dynamic data)? fromJson,
  }) =>
      _send<T>(
        method: 'DELETE',
        path: path,
        query: queryParameters ?? queryParams,
        authToken: authToken,
        transform: fromJson,
      );

  /// Cheap reachability probe used by the "Test connection" control.
  /// Returns the measured latency, or throws [ApiException].
  Future<ApiLogEntry> ping({String path = '/trips/locations'}) async {
    final started = DateTime.now();
    await _send<dynamic>(
      method: 'GET',
      path: path,
      transform: null,
      silent: true,
    );
    final ms = DateTime.now().difference(started).inMilliseconds;
    return ApiLogEntry(
      method: 'GET',
      url: '${ApiConfig.baseUrl}$path',
      statusCode: 200,
      durationMs: ms,
      ok: true,
      detail: 'reachable',
    );
  }

  // ── Core ────────────────────────────────────────────────────────

  /// Runs a request, retrying once **without** the bearer token when the
  /// server rejects the credentials.
  ///
  /// The fleet catalog endpoints (`/trips/locations`, `/trips/routes`,
  /// `/trips/search`) are store-scoped public reads: they authenticate with
  /// `X-Api-Key` + the `apiKey`/`storeId` query params and answer **401/400
  /// when an unexpected `Authorization` header is attached**. Passing the
  /// logged-in user's token to them therefore broke the location list, which
  /// in turn left the search button permanently disabled. Retrying tokenless
  /// keeps those endpoints working while still surfacing genuine auth errors
  /// from endpoints that really do require a token.
  Future<Response<T>> _send<T>({
    required String method,
    required String path,
    Object? data,
    Map<String, dynamic>? query,
    String? authToken,
    T Function(dynamic data)? transform,
    bool silent = false,
  }) async {
    final token = authToken ?? _authToken;
    try {
      return await _attempt<T>(
        method: method,
        path: path,
        data: data,
        query: query,
        token: token,
        transform: transform,
        silent: silent,
      );
    } on ApiException catch (e) {
      final rejected = e.statusCode == 401 || e.statusCode == 403;
      if (token == null || !rejected) rethrow;
      debugPrint('─── API retry: $path rejected the bearer token '
          '(${e.statusCode}); retrying without it');
      return _attempt<T>(
        method: method,
        path: path,
        data: data,
        query: query,
        token: null,
        transform: transform,
        silent: silent,
      );
    }
  }

  Future<Response<T>> _attempt<T>({
    required String method,
    required String path,
    Object? data,
    Map<String, dynamic>? query,
    required String? token,
    T Function(dynamic data)? transform,
    required bool silent,
  }) async {
    final started = DateTime.now();
    try {
      final raw = await _dio.request<dynamic>(
        path,
        data: data,
        queryParameters: query,
        options: Options(
          method: method,
          headers: token == null
              ? null
              : {'Authorization': 'Bearer $token'},
        ),
      );

      final resolved = _resolve<T>(raw.data, transform);
      final elapsed = DateTime.now().difference(started);

      if (!silent) {
        _trace(ApiLogEntry(
          method: method,
          url: _displayUrl(raw.requestOptions),
          statusCode: raw.statusCode,
          durationMs: elapsed.inMilliseconds,
          ok: true,
          detail: _preview(resolved),
        ));
      }

      return Response<T>(
        data: resolved,
        statusCode: raw.statusCode,
        statusMessage: raw.statusMessage,
        isRedirect: raw.isRedirect,
        redirects: raw.redirects,
        extra: raw.extra,
        headers: raw.headers,
        requestOptions: raw.requestOptions,
      );
    } on DioException catch (e) {
      final elapsed = DateTime.now().difference(started);
      final failure = _handleDioException(e);
      if (!silent) {
        final headers = e.requestOptions.headers.entries
            .where((h) => !h.key.toLowerCase().startsWith('content-'))
            .map((h) => '${h.key}: ${_redact(h.key, h.value)}')
            .join(', ');
        _trace(ApiLogEntry(
          method: method,
          url: _displayUrl(e.requestOptions),
          statusCode: e.response?.statusCode,
          durationMs: elapsed.inMilliseconds,
          ok: false,
          detail: '✖ ${failure.message}'
              '\n  request headers: $headers'
              '${e.response?.statusMessage == null ? '' : '\n  statusMessage: ${e.response!.statusMessage}'}'
              '${e.response == null ? '' : '\n  response body: ${_preview(e.response!.data, max: 400)}'}',
        ));
      }
      throw failure;
    }
  }

  /// Applies the caller's transform, or falls back to a checked cast.
  ///
  /// Previously the transform was silently ignored and Dio was asked for
  /// `List<dynamic>` directly; an enveloped `Map` body then failed to cast
  /// and was reported as a network error.
  T _resolve<T>(dynamic body, T Function(dynamic data)? transform) {
    if (transform != null) return transform(body);
    // `is T` is always true when T is dynamic/Object?, which is the common
    // untyped case; for a concrete T it is a real shape check.
    if (body is T) return body;
    throw ApiException(
      'Unexpected response shape: expected $T, got ${body.runtimeType}.',
      data: body,
    );
  }

  // ── Tracing ─────────────────────────────────────────────────────

  static void _trace(ApiLogEntry entry) {
    log.insert(0, entry);
    if (log.length > _maxLogEntries) {
      log.removeRange(_maxLogEntries, log.length);
    }
    if (!debugLogging) return;
    debugPrint('─── API ${entry.ok ? 'OK ' : 'ERR'} ────────────────');
    debugPrint('${entry.method} ${entry.url}');
    debugPrint('status=${entry.statusCode ?? '-'}  ${entry.durationMs}ms');
    debugPrint(entry.detail);
    debugPrint('─────────────────────────────────────');
  }

  static void clearLog() => log.clear();

  /// Never print a full credential into the log.
  static String _redact(String header, String value) {
    final key = header.toLowerCase();
    if (key == 'authorization') {
      return value.length <= 14 ? 'Bearer …' : '${value.substring(0, 11)}…';
    }
    if (key == 'x-api-key') {
      return value.length <= 12
          ? '…'
          : '${value.substring(0, 8)}…${value.substring(value.length - 4)}';
    }
    return value;
  }

  static String _displayUrl(RequestOptions o) {
    final uri = o.uri;
    return uri.hasQuery ? '$uri' : '${o.baseUrl}${o.path}';
  }

  static String _preview(dynamic body, {int max = 900}) {
    String text;
    if (body == null) {
      text = '(empty)';
    } else if (body is String) {
      text = body;
    } else {
      try {
        text = const JsonEncoder.withIndent('  ').convert(body);
      } catch (_) {
        text = '$body';
      }
    }
    return text.length <= max ? text : '${text.substring(0, max)}…';
  }

  // ── Errors ──────────────────────────────────────────────────────

  ApiException _handleDioException(DioException e) {
    final url = _displayUrl(e.requestOptions);

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return ApiException(
          'Timed out after ${e.requestOptions.receiveTimeout?.inSeconds ?? 10}s '
          'talking to $url',
          url: url,
          isNetwork: true,
        );

      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final data = e.response?.data;
        final serverMessage = _extractMessage(data);
        return ApiException(
          serverMessage ??
              'Server responded ${statusCode ?? 'unknown'} for $url',
          statusCode: statusCode,
          data: data,
          url: url,
        );

      case DioExceptionType.cancel:
        return ApiException('Request cancelled', url: url);

      case DioExceptionType.connectionError:
        return ApiException(
          'Cannot reach $url — is the proxy running?',
          url: url,
          isNetwork: true,
        );

      case DioExceptionType.badCertificate:
        return ApiException('Bad TLS certificate for $url',
            url: url, isNetwork: true);

      case DioExceptionType.unknown:
        // Most common real cause here: the server replied 200 with a body
        // whose shape did not match the requested type.
        return ApiException(
          'Could not read the response from $url '
          '(${e.error ?? e.message ?? 'unknown parser error'}).',
          url: url,
          data: e.response?.data,
        );
    }
  }

  /// Pulls a human-readable message out of the API's error envelope.
  static String? _extractMessage(dynamic data) {
    final map = data is Map ? data : null;
    if (map != null) {
      for (final key in const ['Message', 'message', 'error', 'Error',
        'detail', 'Detail', 'title', 'Title']) {
        final v = map[key];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
    }
    if (data is String && data.trim().isNotEmpty) {
      final trimmed = data.trim();
      // Avoid dumping a whole HTML error page into the UI.
      return trimmed.length <= 300 ? trimmed : null;
    }
    return null;
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  /// Fully-resolved request URL, when known.
  final String? url;

  /// True when the request never reached the server (DNS, refused, timeout).
  final bool isNetwork;

  const ApiException(
    this.message, {
    this.statusCode,
    this.data,
    this.url,
    this.isNetwork = false,
  });

  @override
  String toString() => message;
}
