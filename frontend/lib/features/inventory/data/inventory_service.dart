import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import 'inventory_model.dart';

class InventoryService {
  Future<List<SparePart>> getSpareParts({bool includeInactive = false}) async {
    try {
      final response = await ApiClient.dio.get(
        '/api/v1/spare-parts/',
        queryParameters: {'include_inactive': includeInactive},
      );

      return _parseSpareParts(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<List<SparePart>> getLowStockParts() async {
    try {
      final response = await ApiClient.dio.get('/api/v1/spare-parts/low-stock');

      return _parseSpareParts(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<SparePart> getSparePart(int sparePartId) async {
    try {
      final response = await ApiClient.dio.get(
        '/api/v1/spare-parts/$sparePartId',
      );

      return SparePart.fromJson(
        _asResponseMap(
          response.data,
          invalidMessage: 'The server returned an invalid spare-part response.',
        ),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<SparePart> createSparePart(SparePartCreateInput input) async {
    try {
      final response = await ApiClient.dio.post(
        '/api/v1/spare-parts/',
        data: input.toJson(),
      );

      return SparePart.fromJson(
        _asResponseMap(
          response.data,
          invalidMessage: 'The server returned an invalid spare-part response.',
        ),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<SparePart> updateSparePart(
    int sparePartId,
    SparePartUpdateInput input,
  ) async {
    try {
      final response = await ApiClient.dio.patch(
        '/api/v1/spare-parts/$sparePartId',
        data: input.toJson(),
      );

      return SparePart.fromJson(
        _asResponseMap(
          response.data,
          invalidMessage: 'The server returned an invalid spare-part response.',
        ),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<void> deactivateSparePart(int sparePartId) async {
    try {
      await ApiClient.dio.delete('/api/v1/spare-parts/$sparePartId');
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<List<StockTransaction>> getStockTransactions() async {
    try {
      final response = await ApiClient.dio.get(
        '/api/v1/inventory/transactions',
      );

      return _parseStockTransactions(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<List<StockTransaction>> getPartTransactions(int sparePartId) async {
    try {
      final response = await ApiClient.dio.get(
        '/api/v1/inventory/transactions/'
        'part/$sparePartId',
      );

      return _parseStockTransactions(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<List<StockTransaction>> getJobCardTransactions(int jobCardId) async {
    try {
      final response = await ApiClient.dio.get(
        '/api/v1/inventory/transactions/'
        'job-card/$jobCardId',
      );

      return _parseStockTransactions(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<StockTransaction> stockIn(StockInInput input) async {
    try {
      final response = await ApiClient.dio.post(
        '/api/v1/inventory/stock-in',
        data: input.toJson(),
      );

      return StockTransaction.fromJson(
        _asResponseMap(
          response.data,
          invalidMessage: 'The server returned an invalid stock-in response.',
        ),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<StockTransaction> issueStock(StockIssueInput input) async {
    try {
      final response = await ApiClient.dio.post(
        '/api/v1/inventory/issue',
        data: input.toJson(),
      );

      return StockTransaction.fromJson(
        _asResponseMap(
          response.data,
          invalidMessage:
              'The server returned an invalid stock-issue response.',
        ),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<StockTransaction> issueStockToJobCard(StockIssueInput input) async {
    try {
      final response = await ApiClient.dio.post(
        '/api/v1/job-cards/'
        '${input.jobCardId}/spare-parts',
        data: input.toJson(),
      );

      return StockTransaction.fromJson(
        _asResponseMap(
          response.data,
          invalidMessage:
              'The server returned an invalid Job Card spare-part response.',
        ),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<StockTransaction> returnStock(StockReturnInput input) async {
    try {
      final response = await ApiClient.dio.post(
        '/api/v1/inventory/return',
        data: input.toJson(),
      );

      return StockTransaction.fromJson(
        _asResponseMap(
          response.data,
          invalidMessage:
              'The server returned an invalid stock-return response.',
        ),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<StockTransaction> adjustStock(StockAdjustmentInput input) async {
    try {
      final response = await ApiClient.dio.post(
        '/api/v1/inventory/adjust',
        data: input.toJson(),
      );

      return StockTransaction.fromJson(
        _asResponseMap(
          response.data,
          invalidMessage:
              'The server returned an invalid stock-adjustment response.',
        ),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

List<SparePart> _parseSpareParts(dynamic responseData) {
  if (responseData is! List) {
    throw const ApiException(
      message: 'The server returned an invalid spare-parts list.',
    );
  }

  return responseData
      .map((item) {
        return SparePart.fromJson(
          _asResponseMap(
            item,
            invalidMessage: 'The server returned an invalid spare-part item.',
          ),
        );
      })
      .toList(growable: false);
}

List<StockTransaction> _parseStockTransactions(dynamic responseData) {
  if (responseData is! List) {
    throw const ApiException(
      message: 'The server returned an invalid inventory transaction list.',
    );
  }

  return responseData
      .map((item) {
        return StockTransaction.fromJson(
          _asResponseMap(
            item,
            invalidMessage:
                'The server returned an invalid inventory transaction.',
          ),
        );
      })
      .toList(growable: false);
}

Map<String, dynamic> _asResponseMap(
  dynamic responseData, {
  required String invalidMessage,
}) {
  if (responseData is Map<String, dynamic>) {
    return responseData;
  }

  if (responseData is Map) {
    return Map<String, dynamic>.from(responseData);
  }

  throw ApiException(message: invalidMessage);
}
