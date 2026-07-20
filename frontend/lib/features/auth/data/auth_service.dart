import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/token_storage.dart';

class AuthService {
  AuthService({
    TokenStorage? tokenStorage,
  }) : _tokenStorage =
            tokenStorage ?? TokenStorage();

  final TokenStorage _tokenStorage;

  Future<String> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await ApiClient.dio.post(
        '/api/v1/auth/login',
        data: {
          'username': username.trim(),
          'password': password,
        },
      );

      if (response.data is! Map) {
        throw const ApiException(
          message:
              'The server returned an invalid login response.',
        );
      }

      final responseData =
          Map<String, dynamic>.from(
        response.data as Map,
      );

      final token =
          responseData['access_token']?.toString();

      if (token == null || token.isEmpty) {
        throw const ApiException(
          message:
              'The server did not return an access token.',
        );
      }

      await _tokenStorage.saveToken(token);

      ApiClient.setAccessToken(token);

      return token;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<bool> restoreSession() async {
    final token = await _tokenStorage.getToken();

    if (token == null || token.isEmpty) {
      return false;
    }

    ApiClient.setAccessToken(token);

    try {
      await getCurrentUser();
      return true;
    } catch (_) {
      await logout();
      return false;
    }
  }

  Future<Map<String, dynamic>>
      getCurrentUser() async {
    try {
      final response = await ApiClient.dio.get(
        '/api/v1/auth/me',
      );

      if (response.data is! Map) {
        throw const ApiException(
          message:
              'The server returned an invalid user response.',
        );
      }

      return Map<String, dynamic>.from(
        response.data as Map,
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<void> logout() async {
    await _tokenStorage.deleteToken();
    ApiClient.clearAccessToken();
  }
}
