import 'dart:io' show File;

import 'package:dio/dio.dart';

import 'session.dart';

/// Thin wrapper around Dio configured for the Nestora backend.
///
/// Base URL notes:
/// - Defaults to the production EC2 box, so builds installed on a real phone
///   reach a server that actually exists. `10.0.2.2`/`localhost` only resolve
///   from an emulator or the host machine, never from a physical device.
/// - To run against a local backend, override at build time:
///   `flutter run --dart-define=API_ORIGIN=http://10.0.2.2:3000`
class ApiClient {
  ApiClient._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = Session.instance.token;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  static final ApiClient instance = ApiClient._();

  late final Dio _dio;

  /// Origin the API hangs off, overridable per build. nginx on the prod box
  /// proxies `/` to the backend on :3000, so no port is needed there.
  static const String _origin = String.fromEnvironment(
    'API_ORIGIN',
    defaultValue: 'http://ec2-44-201-139-203.compute-1.amazonaws.com',
  );

  static String get _baseUrl => '$_origin/api';

  /// Turns a stored `/uploads/x.jpg` into a URL the app can load.
  ///
  /// Uploads are served as static files, which bypass the backend's `api`
  /// prefix — so they hang off the origin, not [_baseUrl]. Returns null for a
  /// null/empty path so callers can fall back to an initial.
  static String? imageUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    final origin = _baseUrl.substring(0, _baseUrl.length - '/api'.length);
    return '$origin$path';
  }

  /// Uploads an image and returns its stored path (e.g. `/uploads/x.jpg`).
  Future<String> uploadImage(File file) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path),
    });
    final res = await _dio.post('/uploads', data: form);
    return (res.data as Map)['url'] as String;
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    final res = await _dio.get(path, queryParameters: query);
    return res.data;
  }

  Future<dynamic> post(String path, {Object? body}) async {
    final res = await _dio.post(path, data: body);
    return res.data;
  }

  Future<dynamic> patch(String path, {Object? body}) async {
    final res = await _dio.patch(path, data: body);
    return res.data;
  }

  /// [body] is for the rare delete that identifies its target by payload
  /// rather than by path — dropping a device token, for instance.
  Future<dynamic> delete(String path, {Object? body}) async {
    final res = await _dio.delete(path, data: body);
    return res.data;
  }

  /// Turns a Dio error into a short, user-friendly message.
  static String messageFor(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['message'] != null) {
        final msg = data['message'];
        return msg is List ? msg.join(', ') : msg.toString();
      }
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout) {
        return 'Cannot reach the server. Is the backend running?';
      }
    }
    return 'Something went wrong';
  }
}
