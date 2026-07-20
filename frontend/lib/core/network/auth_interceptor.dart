import 'package:dio/dio.dart';

import 'token_storage.dart';

typedef UnauthorizedHandler = Future<void> Function();

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokenStorage, this._onUnauthorized);

  final TokenStorage _tokenStorage;
  final UnauthorizedHandler _onUnauthorized;

  bool _isHandlingUnauthorized = false;

  bool _isAuthenticationEndpoint(String path) {
    return path.endsWith('/auth/login') || path.endsWith('/auth/register');
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final path = options.uri.path;

      if (_isAuthenticationEndpoint(path)) {
        options.headers.remove('Authorization');
        handler.next(options);
        return;
      }

      final token = await _tokenStorage.getToken();

      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      } else {
        options.headers.remove('Authorization');
      }

      handler.next(options);
    } catch (error) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: error,
          message: 'Failed to prepare authentication request.',
        ),
      );
    }
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final statusCode = err.response?.statusCode;
    final path = err.requestOptions.uri.path;

    final shouldLogout = statusCode == 401 && !_isAuthenticationEndpoint(path);

    if (shouldLogout && !_isHandlingUnauthorized) {
      _isHandlingUnauthorized = true;

      try {
        await _tokenStorage.deleteToken();
        await _onUnauthorized();
      } finally {
        _isHandlingUnauthorized = false;
      }
    }

    handler.next(err);
  }
}
