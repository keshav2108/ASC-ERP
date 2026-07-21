import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import 'payment_model.dart';

class PaymentService {
  Future<List<Payment>> getPayments() async {
    try {
      final response = await ApiClient.dio.get('/api/v1/payments/');

      return _parsePayments(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Payment> getPayment(int paymentId) async {
    try {
      final response = await ApiClient.dio.get('/api/v1/payments/$paymentId');

      return Payment.fromJson(_asResponseMap(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<InvoicePaymentSummary> getInvoicePayments(int invoiceId) async {
    try {
      final response = await ApiClient.dio.get(
        '/api/v1/payments/invoice/$invoiceId',
      );

      return InvoicePaymentSummary.fromJson(_asResponseMap(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Payment> createPayment(PaymentCreateInput input) async {
    try {
      final response = await ApiClient.dio.post(
        '/api/v1/payments/',
        data: input.toJson(),
      );

      return Payment.fromJson(_asResponseMap(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Payment> cancelPayment(int paymentId) async {
    try {
      final response = await ApiClient.dio.post(
        '/api/v1/payments/$paymentId/cancel',
      );

      return Payment.fromJson(_asResponseMap(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

List<Payment> _parsePayments(dynamic responseData) {
  if (responseData is! List) {
    throw const ApiException(
      message: 'The server returned an invalid payment list.',
    );
  }

  return responseData
      .whereType<Map>()
      .map((payment) => Payment.fromJson(Map<String, dynamic>.from(payment)))
      .toList();
}

Map<String, dynamic> _asResponseMap(dynamic responseData) {
  if (responseData is Map<String, dynamic>) {
    return responseData;
  }

  if (responseData is Map) {
    return Map<String, dynamic>.from(responseData);
  }

  throw const ApiException(
    message: 'The server returned an invalid payment response.',
  );
}
