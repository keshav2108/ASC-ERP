import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../data/notification_model.dart';
import '../data/notification_provider.dart';

typedef NotificationOpenCallback =
    Future<void> Function(AppNotification notification);

Future<void> showNotificationPanel({
  required BuildContext context,
  required NotificationOpenCallback onOpenNotification,
}) async {
  final screenSize = MediaQuery.sizeOf(context);
  final useDesktopDialog = screenSize.width >= 700;

  if (useDesktopDialog) {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (dialogContext) {
        return Dialog(
          alignment: Alignment.topRight,
          insetPadding: const EdgeInsets.only(
            top: 78,
            right: 24,
            bottom: 24,
            left: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 390,
              maxWidth: 430,
              maxHeight: 650,
            ),
            child: NotificationPanel(onOpenNotification: onOpenNotification),
          ),
        );
      },
    );

    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return FractionallySizedBox(
        heightFactor: 0.82,
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          clipBehavior: Clip.antiAlias,
          child: NotificationPanel(onOpenNotification: onOpenNotification),
        ),
      );
    },
  );
}

class NotificationPanel extends ConsumerWidget {
  const NotificationPanel({required this.onOpenNotification, super.key});

  final NotificationOpenCallback onOpenNotification;

  Future<void> _refresh(WidgetRef ref) {
    return ref.read(notificationProvider.notifier).refreshNotifications();
  }

  Future<void> _markAllAsRead(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(notificationProvider.notifier).markAllAsRead();
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      _showMessage(context, _cleanError(error), isError: true);
    }
  }

  Future<void> _openNotification(
    BuildContext context,
    WidgetRef ref,
    AppNotification notification,
  ) async {
    try {
      var selectedNotification = notification;

      if (notification.isUnread) {
        selectedNotification = await ref
            .read(notificationProvider.notifier)
            .markAsRead(notification.id);
      }

      if (!context.mounted) {
        return;
      }

      Navigator.of(context).pop();

      await Future<void>.delayed(Duration.zero);

      await onOpenNotification(selectedNotification);
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      _showMessage(context, _cleanError(error), isError: true);
    }
  }

  void _showMessage(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppColors.danger : AppColors.success,
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsState = ref.watch(notificationProvider);

    final unreadCount = notificationsState.value?.unreadCount ?? 0;

    return Material(
      color: AppColors.surface,
      child: Column(
        children: [
          _NotificationPanelHeader(
            unreadCount: unreadCount,
            isRefreshing: notificationsState.isLoading,
            onRefresh: () {
              _refresh(ref);
            },
            onMarkAllAsRead: unreadCount == 0
                ? null
                : () {
                    _markAllAsRead(context, ref);
                  },
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: notificationsState.when(
              loading: () {
                return const _NotificationLoading();
              },
              error: (error, stackTrace) {
                return _NotificationError(
                  message: _cleanError(error),
                  onRetry: () {
                    _refresh(ref);
                  },
                );
              },
              data: (notificationState) {
                if (notificationState.isEmpty) {
                  return const _NotificationEmpty();
                }

                return RefreshIndicator(
                  onRefresh: () => _refresh(ref),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    itemCount: notificationState.notifications.length,
                    separatorBuilder: (context, index) {
                      return const Divider(
                        height: 1,
                        indent: 78,
                        color: AppColors.border,
                      );
                    },
                    itemBuilder: (context, index) {
                      final notification =
                          notificationState.notifications[index];

                      return _NotificationTile(
                        notification: notification,
                        onTap: () {
                          _openNotification(context, ref, notification);
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationPanelHeader extends StatelessWidget {
  const _NotificationPanelHeader({
    required this.unreadCount,
    required this.isRefreshing,
    required this.onRefresh,
    required this.onMarkAllAsRead,
  });

  final int unreadCount;
  final bool isRefreshing;
  final VoidCallback onRefresh;
  final VoidCallback? onMarkAllAsRead;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.notifications_rounded,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  unreadCount == 0
                      ? 'You are all caught up'
                      : '$unreadCount unread',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onMarkAllAsRead,
            child: const Text('Mark all read'),
          ),
          IconButton(
            tooltip: 'Refresh notifications',
            onPressed: isRefreshing ? null : onRefresh,
            icon: isRefreshing
                ? const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isUnread = notification.isUnread;

    return Material(
      color: isUnread
          ? AppColors.primary.withValues(alpha: 0.045)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 15, 16, 15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _notificationColor(
                        notification,
                      ).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _notificationIcon(notification),
                      color: _notificationColor(notification),
                      size: 23,
                    ),
                  ),
                  if (isUnread)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: const BoxDecoration(
                          color: AppColors.danger,
                          shape: BoxShape.circle,
                          border: Border.fromBorderSide(
                            BorderSide(color: AppColors.surface, width: 2),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: isUnread
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatRelativeTime(notification.createdAt),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      notification.message,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    if (notification.isJobCardNotification) ...[
                      const SizedBox(height: 8),
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Open Job Card',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 3),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 15,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationLoading extends StatelessWidget {
  const _NotificationLoading();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: 5,
      separatorBuilder: (context, index) {
        return const Divider(height: 1, indent: 78, color: AppColors.border);
      },
      itemBuilder: (context, index) {
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 17),
          child: Row(
            children: [
              _LoadingBlock(width: 44, height: 44),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LoadingBlock(width: 170, height: 13),
                    SizedBox(height: 9),
                    _LoadingBlock(width: double.infinity, height: 11),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.border.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

class _NotificationEmpty extends StatelessWidget {
  const _NotificationEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: 56,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: 16),
            Text(
              'No notifications yet',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 7),
            Text(
              'New assignments and important updates will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationError extends StatelessWidget {
  const _NotificationError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 52,
              color: AppColors.danger,
            ),
            const SizedBox(height: 15),
            const Text(
              'Unable to load notifications',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _notificationIcon(AppNotification notification) {
  switch (notification.notificationType.trim().toUpperCase()) {
    case 'NEW_JOB_ASSIGNED':
      return Icons.assignment_ind_rounded;

    case 'JOB_REOPENED':
      return Icons.replay_circle_filled_rounded;

    default:
      return Icons.notifications_rounded;
  }
}

Color _notificationColor(AppNotification notification) {
  switch (notification.notificationType.trim().toUpperCase()) {
    case 'NEW_JOB_ASSIGNED':
      return AppColors.primary;

    case 'JOB_REOPENED':
      return AppColors.warning;

    default:
      return AppColors.info;
  }
}

String _formatRelativeTime(DateTime createdAt) {
  final difference = DateTime.now().difference(createdAt);

  if (difference.isNegative) {
    return 'Just now';
  }

  if (difference.inSeconds < 60) {
    return 'Just now';
  }

  if (difference.inMinutes < 60) {
    return '${difference.inMinutes}m';
  }

  if (difference.inHours < 24) {
    return '${difference.inHours}h';
  }

  if (difference.inDays < 7) {
    return '${difference.inDays}d';
  }

  final day = createdAt.day.toString().padLeft(2, '0');

  final month = createdAt.month.toString().padLeft(2, '0');

  return '$day/$month';
}

String _cleanError(Object error) {
  return error.toString().replaceFirst('Exception: ', '').trim();
}
