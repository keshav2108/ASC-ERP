import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import 'customer_model.dart';

class CustomerService {
  Future<List<Customer>> getCustomers() async {
    try {
      final response = await ApiClient.dio.get('/api/v1/customers/');

      if (response.data is! List) {
        throw const ApiException(
          message: 'The server returned an invalid customer list.',
        );
      }

      return (response.data as List)
          .map(
            (item) => Customer.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Customer> getCustomerById(int customerId) async {
    try {
      final response = await ApiClient.dio.get('/api/v1/customers/$customerId');

      return Customer.fromJson(Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Customer> createCustomer(CustomerInput input) async {
    try {
      final response = await ApiClient.dio.post(
        '/api/v1/customers/',
        data: input.toJson(),
      );

      return Customer.fromJson(Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Customer> updateCustomer(int customerId, CustomerInput input) async {
    try {
      final response = await ApiClient.dio.put(
        '/api/v1/customers/$customerId',
        data: input.toJson(),
      );

      return Customer.fromJson(Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<void> deactivateCustomer(int customerId) async {
    try {
      await ApiClient.dio.delete('/api/v1/customers/$customerId');
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
