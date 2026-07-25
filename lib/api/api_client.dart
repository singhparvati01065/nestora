import 'dart:io' show File, Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'session.dart';

/// Thin wrapper around Dio configured for the Nestora backend.
///
/// Base URL notes:
/// - Android emulator reaches the host machine at `10.0.2.2`, not `localhost`.
/// - iOS simulator / desktop use `localhost`.
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

  static String get _baseUrl {
    const port = 3000;
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:$port/api';
    }
    return 'http://localhost:$port/api';
  }

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

  Future<dynamic> delete(String path) async {
    final res = await _dio.delete(path);
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
