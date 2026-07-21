import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import 'invoice_model.dart';

class InvoiceService {
  Future<List<Invoice>> getInvoices() async {
    try {
      final response = await ApiClient.dio.get('/api/v1/invoices/');

      return _parseInvoices(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Invoice> createInvoice(InvoiceCreateInput input) async {
    try {
      final response = await ApiClient.dio.post(
        '/api/v1/invoices/',
        data: input.toJson(),
      );

      return Invoice.fromJson(_asResponseMap(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Invoice> getInvoice(int invoiceId) async {
    try {
      final response = await ApiClient.dio.get('/api/v1/invoices/$invoiceId');

      return Invoice.fromJson(_asResponseMap(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Invoice> getInvoiceByJobCard(int jobCardId) async {
    try {
      final response = await ApiClient.dio.get(
        '/api/v1/invoices/job-card/$jobCardId',
      );

      return Invoice.fromJson(_asResponseMap(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Invoice> cancelInvoice(int invoiceId) async {
    try {
      final response = await ApiClient.dio.post(
        '/api/v1/invoices/$invoiceId/cancel',
      );

      return Invoice.fromJson(_asResponseMap(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

List<Invoice> _parseInvoices(dynamic responseData) {
  if (responseData is! List) {
    throw const ApiException(
      message: 'The server returned an invalid invoice list.',
    );
  }

  return responseData
      .whereType<Map>()
      .map((item) => Invoice.fromJson(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}

Map<String, dynamic> _asResponseMap(dynamic responseData) {
  if (responseData is Map<String, dynamic>) {
    return responseData;
  }

  if (responseData is Map) {
    return Map<String, dynamic>.from(responseData);
  }

  throw const ApiException(
    message: 'The server returned an invalid invoice response.',
  );
}
