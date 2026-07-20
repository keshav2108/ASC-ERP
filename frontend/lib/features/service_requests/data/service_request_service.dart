import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import 'service_request_model.dart';

class ServiceRequestService {
  Future<List<ServiceRequest>> getServiceRequests() async {
    try {
      final response = await ApiClient.dio.get('/api/v1/service-requests/');

      return _parseServiceRequests(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<ServiceRequest> createServiceRequest(
    ServiceRequestCreateInput input,
  ) async {
    try {
      final response = await ApiClient.dio.post(
        '/api/v1/service-requests/',
        data: input.toJson(),
      );

      return ServiceRequest.fromJson(_asResponseMap(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<ServiceRequest> updateServiceRequest(
    int serviceRequestId,
    ServiceRequestUpdateInput input,
  ) async {
    try {
      final response = await ApiClient.dio.patch(
        '/api/v1/service-requests/$serviceRequestId',
        data: input.toJson(),
      );

      return ServiceRequest.fromJson(_asResponseMap(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<void> cancelServiceRequest(int serviceRequestId) async {
    try {
      await ApiClient.dio.delete('/api/v1/service-requests/$serviceRequestId');
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<List<CustomerProduct>> getCustomerProducts(int customerId) async {
    try {
      final response = await ApiClient.dio.get(
        '/api/v1/customer-products/customer/$customerId',
      );

      if (response.data is! List) {
        throw const ApiException(
          message: 'The server returned an invalid product list.',
        );
      }

      return (response.data as List)
          .map(
            (item) => CustomerProduct.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<List<MasterOption>> getMasterOptions(String optionType) async {
    try {
      final response = await ApiClient.dio.get(
        '/api/v1/master-options/type/$optionType',
      );

      if (response.data is! List) {
        throw const ApiException(
          message: 'The server returned invalid master options.',
        );
      }

      return (response.data as List)
          .map(
            (item) =>
                MasterOption.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .where((option) => option.isActive)
          .toList()
        ..sort(
          (first, second) => first.displayOrder.compareTo(second.displayOrder),
        );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

List<ServiceRequest> _parseServiceRequests(dynamic responseData) {
  if (responseData is! List) {
    throw const ApiException(
      message: 'The server returned an invalid service-request list.',
    );
  }

  return responseData
      .map(
        (item) =>
            ServiceRequest.fromJson(Map<String, dynamic>.from(item as Map)),
      )
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
    message: 'The server returned an invalid service-request response.',
  );
}
