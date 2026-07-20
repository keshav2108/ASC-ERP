import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import 'dashboard_model.dart';

class DashboardService {
  Future<DashboardOverview> getOverview() async {
    try {
      final response = await ApiClient.dio.get('/api/v1/dashboard/overview');

      if (response.data is! Map) {
        throw const ApiException(
          message: 'The server returned an invalid dashboard response.',
        );
      }

      final data = Map<String, dynamic>.from(response.data as Map);

      return DashboardOverview.fromJson(data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
