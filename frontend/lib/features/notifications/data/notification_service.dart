import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import 'notification_model.dart';

class NotificationService {
  Future<List<AppNotification>> getNotifications({
    bool unreadOnly = false,
    int offset = 0,
    int limit = 50,
  }) async {
    try {
      final response = await ApiClient.dio.get(
        '/api/v1/notifications',
        queryParameters: {
          'unread_only': unreadOnly,
          'offset': offset,
          'limit': limit,
        },
      );

      return _parseNotificationList(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<int> getUnreadCount() async {
    try {
      final response = await ApiClient.dio.get(
        '/api/v1/notifications/unread-count',
      );

      final responseData = _asResponseMap(response.data);

      return _asInt(responseData['unread_count']);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<AppNotification> markNotificationAsRead(int notificationId) async {
    try {
      final response = await ApiClient.dio.patch(
        '/api/v1/notifications/$notificationId/read',
      );

      return AppNotification.fromJson(_asResponseMap(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<int> markAllNotificationsAsRead() async {
    try {
      final response = await ApiClient.dio.patch(
        '/api/v1/notifications/read-all',
      );

      final responseData = _asResponseMap(response.data);

      return _asInt(responseData['updated_count']);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

List<AppNotification> _parseNotificationList(dynamic responseData) {
  if (responseData is! List) {
    throw const ApiException(
      message: 'The server returned an invalid notification list.',
    );
  }

  return responseData
      .whereType<Map>()
      .map(
        (notification) =>
            AppNotification.fromJson(Map<String, dynamic>.from(notification)),
      )
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
    message: 'The server returned an invalid notification response.',
  );
}

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString().trim() ?? '') ?? 0;
}
