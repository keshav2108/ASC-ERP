import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notification_model.dart';
import 'notification_service.dart';

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);

class NotificationState {
  const NotificationState({
    required this.notifications,
    required this.unreadCount,
    required this.lastUpdatedAt,
  });

  const NotificationState.empty()
    : notifications = const <AppNotification>[],
      unreadCount = 0,
      lastUpdatedAt = null;

  final List<AppNotification> notifications;
  final int unreadCount;
  final DateTime? lastUpdatedAt;

  bool get hasUnreadNotifications {
    return unreadCount > 0;
  }

  bool get isEmpty {
    return notifications.isEmpty;
  }

  NotificationState copyWith({
    List<AppNotification>? notifications,
    int? unreadCount,
    DateTime? lastUpdatedAt,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }
}

class NotificationNotifier extends AsyncNotifier<NotificationState> {
  static const Duration _refreshInterval = Duration(seconds: 30);

  late final NotificationService _service;

  bool _refreshInProgress = false;

  @override
  Future<NotificationState> build() async {
    _service = ref.read(notificationServiceProvider);

    final initialState = await _loadNotificationState();

    final refreshTimer = Timer.periodic(_refreshInterval, (_) {
      unawaited(refreshNotifications(showLoading: false));
    });

    ref.onDispose(refreshTimer.cancel);

    return initialState;
  }

  Future<NotificationState> _loadNotificationState() async {
    final results = await Future.wait<dynamic>([
      _service.getNotifications(),
      _service.getUnreadCount(),
    ]);

    final notifications = results[0] as List<AppNotification>;

    final unreadCount = results[1] as int;

    return NotificationState(
      notifications: notifications,
      unreadCount: unreadCount,
      lastUpdatedAt: DateTime.now(),
    );
  }

  Future<void> refreshNotifications({bool showLoading = true}) async {
    if (_refreshInProgress) {
      return;
    }

    _refreshInProgress = true;

    final previousState = state;

    if (showLoading) {
      state = const AsyncLoading();
    }

    try {
      final refreshedState = await AsyncValue.guard(_loadNotificationState);

      if (!showLoading && refreshedState.hasError && previousState.hasValue) {
        return;
      }

      state = refreshedState;
    } finally {
      _refreshInProgress = false;
    }
  }

  Future<void> refreshSilently() {
    return refreshNotifications(showLoading: false);
  }

  Future<AppNotification> markAsRead(int notificationId) async {
    final updatedNotification = await _service.markNotificationAsRead(
      notificationId,
    );

    final currentState = state.value;

    if (currentState == null) {
      await refreshSilently();

      return updatedNotification;
    }

    AppNotification? previousNotification;

    for (final notification in currentState.notifications) {
      if (notification.id == notificationId) {
        previousNotification = notification;
        break;
      }
    }

    final updatedNotifications = currentState.notifications
        .map((notification) {
          if (notification.id == notificationId) {
            return updatedNotification;
          }

          return notification;
        })
        .toList(growable: false);

    final shouldDecreaseUnread =
        previousNotification?.isUnread == true && updatedNotification.isRead;

    final nextUnreadCount = shouldDecreaseUnread
        ? currentState.unreadCount > 0
              ? currentState.unreadCount - 1
              : 0
        : currentState.unreadCount;

    state = AsyncData(
      currentState.copyWith(
        notifications: updatedNotifications,
        unreadCount: nextUnreadCount,
        lastUpdatedAt: DateTime.now(),
      ),
    );

    return updatedNotification;
  }

  Future<int> markAllAsRead() async {
    final updatedCount = await _service.markAllNotificationsAsRead();

    final currentState = state.value;

    if (currentState == null) {
      await refreshSilently();

      return updatedCount;
    }

    if (currentState.unreadCount == 0) {
      return updatedCount;
    }

    final localReadTime = DateTime.now();

    final updatedNotifications = currentState.notifications
        .map((notification) {
          if (!notification.isUnread) {
            return notification;
          }

          return notification.copyWith(status: 'READ', readAt: localReadTime);
        })
        .toList(growable: false);

    state = AsyncData(
      currentState.copyWith(
        notifications: updatedNotifications,
        unreadCount: 0,
        lastUpdatedAt: localReadTime,
      ),
    );

    unawaited(refreshSilently());

    return updatedCount;
  }
}

final notificationProvider =
    AsyncNotifierProvider.autoDispose<NotificationNotifier, NotificationState>(
      NotificationNotifier.new,
    );

final unreadNotificationCountProvider = Provider.autoDispose<int>((ref) {
  return ref.watch(notificationProvider).value?.unreadCount ?? 0;
});

final hasUnreadNotificationsProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(unreadNotificationCountProvider) > 0;
});
