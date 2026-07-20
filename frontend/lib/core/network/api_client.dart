import 'package:dio/dio.dart';

import 'auth_interceptor.dart';
import 'token_storage.dart';

class ApiClient {
  ApiClient._();

  static final TokenStorage _tokenStorage = TokenStorage();

  static UnauthorizedHandler? _onUnauthorized;

  static bool _isConfigured = false;

  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: 'http://127.0.0.1:8000',
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );

  static void configure({required UnauthorizedHandler onUnauthorized}) {
    _onUnauthorized = onUnauthorized;

    if (_isConfigured) {
      return;
    }

    dio.interceptors.add(
      AuthInterceptor(_tokenStorage, () async {
        final callback = _onUnauthorized;

        if (callback != null) {
          await callback();
        }
      }),
    );

    _isConfigured = true;
  }

  static void setAccessToken(String token) {
    dio.options.headers['Authorization'] = 'Bearer $token';
  }

  static void clearAccessToken() {
    dio.options.headers.remove('Authorization');
  }
}
