/// LendLoop API Client
///
/// Dio HTTP client with:
/// - Auth token injection via interceptor
/// - 401 refresh token handling
/// - Error transformation
/// - Logging in debug mode

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lendloop/core/constants/app_constants.dart';

class ApiClient {
  static ApiClient? _instance;
  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  ApiClient._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: const Duration(milliseconds: AppConstants.connectTimeout),
        receiveTimeout: const Duration(milliseconds: AppConstants.receiveTimeout),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    _setupInterceptors();
  }

  static ApiClient get instance => _instance ??= ApiClient._();

  Dio get dio => _dio;

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: AppConstants.accessTokenKey);
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401) {
            // Attempt token refresh
            final refreshed = await _tryRefreshToken();
            if (refreshed) {
              // Retry original request
              final token = await _storage.read(key: AppConstants.accessTokenKey);
              e.requestOptions.headers['Authorization'] = 'Bearer $token';
              final response = await _dio.fetch(e.requestOptions);
              return handler.resolve(response);
            }
          }
          handler.next(e);
        },
      ),
    );
  }

  Future<bool> _tryRefreshToken() async {
    try {
      final refreshToken = await _storage.read(key: AppConstants.refreshTokenKey);
      if (refreshToken == null) return false;

      final response = await _dio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final newToken = response.data['access_token'];
      await _storage.write(key: AppConstants.accessTokenKey, value: newToken);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Response> get(String path, {Map<String, dynamic>? params}) async {
    return await _dio.get(path, queryParameters: params);
  }

  Future<Response> post(String path, {dynamic data}) async {
    return await _dio.post(path, data: data);
  }

  Future<Response> put(String path, {dynamic data}) async {
    return await _dio.put(path, data: data);
  }

  Future<Response> delete(String path) async {
    return await _dio.delete(path);
  }

  Future<Response> uploadFile(
    String path,
    FormData formData,
    {void Function(int, int)? onProgress}
  ) async {
    return await _dio.post(
      path,
      data: formData,
      onSendProgress: onProgress,
    );
  }
}
