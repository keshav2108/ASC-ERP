import 'package:dio/dio.dart';

class ApiException implements Exception {
  const ApiException({required this.message, this.statusCode, this.details});

  final String message;
  final int? statusCode;
  final dynamic details;

  factory ApiException.fromDio(DioException error) {
    final statusCode = error.response?.statusCode;
    final responseData = error.response?.data;

    if (responseData is Map) {
      final data = Map<String, dynamic>.from(responseData);

      final serverMessage = data['message'] ?? data['detail'];

      if (serverMessage != null) {
        return ApiException(
          message: serverMessage.toString(),
          statusCode: statusCode,
          details: data['details'],
        );
      }
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return const ApiException(
          message: 'Connection timed out. Please try again.',
        );

      case DioExceptionType.sendTimeout:
        return const ApiException(
          message: 'The request took too long to send.',
        );

      case DioExceptionType.receiveTimeout:
        return const ApiException(
          message: 'The server took too long to respond.',
        );

      case DioExceptionType.transformTimeout:
        return const ApiException(
          message: 'The server response took too long to process.',
        );

      case DioExceptionType.connectionError:
        return const ApiException(
          message:
              'Cannot connect to the server. '
              'Make sure FastAPI is running.',
        );

      case DioExceptionType.badCertificate:
        return const ApiException(
          message: 'The server certificate is invalid.',
        );

      case DioExceptionType.cancel:
        return const ApiException(message: 'The request was cancelled.');

      case DioExceptionType.badResponse:
        return ApiException(
          message:
              'Server request failed with status '
              '${statusCode ?? 'unknown'}.',
          statusCode: statusCode,
        );

      case DioExceptionType.unknown:
        return const ApiException(
          message: 'An unexpected network error occurred.',
        );
    }
  }

  @override
  String toString() => message;
}
