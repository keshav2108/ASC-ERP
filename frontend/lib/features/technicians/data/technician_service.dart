import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import 'technician_model.dart';

class TechnicianService {
  Future<List<Technician>> getTechnicians() async {
    try {
      final response = await ApiClient.dio.get('/api/v1/technicians/');

      return _parseTechnicians(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Technician> getTechnician(int technicianId) async {
    try {
      final response = await ApiClient.dio.get(
        '/api/v1/technicians/$technicianId',
      );

      return Technician.fromJson(_asResponseMap(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Technician> createTechnician(TechnicianCreateInput input) async {
    try {
      final response = await ApiClient.dio.post(
        '/api/v1/technicians/',
        data: input.toJson(),
      );

      return Technician.fromJson(_asResponseMap(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Technician> updateTechnician(
    int technicianId,
    TechnicianUpdateInput input,
  ) async {
    try {
      final response = await ApiClient.dio.patch(
        '/api/v1/technicians/$technicianId',
        data: input.toJson(),
      );

      return Technician.fromJson(_asResponseMap(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<void> deactivateTechnician(int technicianId) async {
    try {
      await ApiClient.dio.delete('/api/v1/technicians/$technicianId');
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

List<Technician> _parseTechnicians(dynamic responseData) {
  if (responseData is! List) {
    throw const ApiException(
      message: 'The server returned an invalid technician list.',
    );
  }

  return responseData
      .map(
        (item) => Technician.fromJson(Map<String, dynamic>.from(item as Map)),
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
    message: 'The server returned an invalid technician response.',
  );
}
