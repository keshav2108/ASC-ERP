class AppNotification {
  const AppNotification({
    required this.id,
    required this.recipientUserId,
    required this.notificationType,
    required this.title,
    required this.message,
    required this.status,
    required this.createdAt,
    this.createdByUserId,
    this.entityType,
    this.entityId,
    this.readAt,
  });

  final int id;
  final int recipientUserId;
  final int? createdByUserId;

  final String notificationType;
  final String title;
  final String message;

  final String? entityType;
  final int? entityId;

  final String status;
  final DateTime? readAt;
  final DateTime createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: _asInt(json['id']),
      recipientUserId: _asInt(json['recipient_user_id']),
      createdByUserId: _asNullableInt(json['created_by_user_id']),
      notificationType: _asString(json['notification_type']),
      title: _asString(json['title']),
      message: _asString(json['message']),
      entityType: _asNullableString(json['entity_type']),
      entityId: _asNullableInt(json['entity_id']),
      status: _asString(json['status']),
      readAt: _asNullableDateTime(json['read_at']),
      createdAt: _asDateTime(json['created_at']),
    );
  }

  bool get isUnread {
    return status.trim().toUpperCase() == 'UNREAD';
  }

  bool get isRead {
    return status.trim().toUpperCase() == 'READ';
  }

  bool get isJobCardNotification {
    return entityType?.trim().toUpperCase() == 'JOB_CARD' && entityId != null;
  }

  AppNotification copyWith({
    String? status,
    DateTime? readAt,
    bool clearReadAt = false,
  }) {
    return AppNotification(
      id: id,
      recipientUserId: recipientUserId,
      createdByUserId: createdByUserId,
      notificationType: notificationType,
      title: title,
      message: message,
      entityType: entityType,
      entityId: entityId,
      status: status ?? this.status,
      readAt: clearReadAt ? null : readAt ?? this.readAt,
      createdAt: createdAt,
    );
  }
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

int? _asNullableInt(Object? value) {
  if (value == null) {
    return null;
  }

  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  final parsed = int.tryParse(value.toString().trim());

  return parsed;
}

String _asString(Object? value) {
  return value?.toString().trim() ?? '';
}

String? _asNullableString(Object? value) {
  final text = value?.toString().trim();

  if (text == null || text.isEmpty) {
    return null;
  }

  return text;
}

DateTime _asDateTime(Object? value) {
  if (value is DateTime) {
    return value;
  }

  return DateTime.tryParse(value?.toString().trim() ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime? _asNullableDateTime(Object? value) {
  if (value == null) {
    return null;
  }

  if (value is DateTime) {
    return value;
  }

  final text = value.toString().trim();

  if (text.isEmpty) {
    return null;
  }

  return DateTime.tryParse(text);
}
