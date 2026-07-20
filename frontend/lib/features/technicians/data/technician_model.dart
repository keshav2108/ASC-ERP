class Technician {
  const Technician({
    required this.id,
    required this.technicianCode,
    required this.userId,
    required this.fullName,
    required this.mobile,
    required this.specialization,
    required this.experienceYears,
    required this.availabilityStatus,
    required this.status,
    required this.createdAt,
  });

  final int id;
  final String technicianCode;
  final int? userId;

  final String fullName;
  final String mobile;
  final String? specialization;

  final int experienceYears;

  final String availabilityStatus;
  final String status;

  final DateTime createdAt;

  bool get isActive {
    return status.toUpperCase() == 'ACTIVE';
  }

  bool get isAvailable {
    return isActive;
  }

  String get displayName {
    return '$fullName ($technicianCode)';
  }

  factory Technician.fromJson(Map<String, dynamic> json) {
    return Technician(
      id: _asInt(json['id']),
      technicianCode: _asString(json['technician_code']),
      userId: _asNullableInt(json['user_id']),
      fullName: _asString(json['full_name']),
      mobile: _asString(json['mobile']),
      specialization: _asNullableString(json['specialization']),
      experienceYears: _asInt(json['experience_years']),
      availabilityStatus: _asString(json['availability_status']),
      status: _asString(json['status']),
      createdAt: _asDate(json['created_at']),
    );
  }
}

class TechnicianCreateInput {
  const TechnicianCreateInput({
    required this.fullName,
    required this.mobile,
    this.userId,
    this.specialization,
    this.experienceYears = 0,
  });

  final int? userId;
  final String fullName;
  final String mobile;
  final String? specialization;
  final int experienceYears;

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'full_name': fullName.trim(),
      'mobile': mobile.trim(),
      'specialization': _emptyToNull(specialization),
      'experience_years': experienceYears,
    };
  }
}

class TechnicianUpdateInput {
  const TechnicianUpdateInput({
    this.userId,
    this.fullName,
    this.mobile,
    this.specialization,
    this.experienceYears,
    this.availabilityStatus,
    this.status,
    this.includeUserId = false,
    this.includeSpecialization = false,
  });

  final int? userId;
  final String? fullName;
  final String? mobile;
  final String? specialization;
  final int? experienceYears;
  final String? availabilityStatus;
  final String? status;

  final bool includeUserId;
  final bool includeSpecialization;

  Map<String, dynamic> toJson() {
    return {
      if (includeUserId) 'user_id': userId,
      if (fullName != null) 'full_name': fullName!.trim(),
      if (mobile != null) 'mobile': mobile!.trim(),
      if (includeSpecialization) 'specialization': _emptyToNull(specialization),
      if (experienceYears != null) 'experience_years': experienceYears,
      if (availabilityStatus != null) 'availability_status': availabilityStatus,
      if (status != null) 'status': status,
    };
  }
}

String _asString(dynamic value) {
  return value?.toString() ?? '';
}

String? _asNullableString(dynamic value) {
  final text = value?.toString().trim();

  if (text == null || text.isEmpty) {
    return null;
  }

  return text;
}

int _asInt(dynamic value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _asNullableInt(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value.toString());
}

DateTime _asDate(dynamic value) {
  return DateTime.tryParse(value?.toString() ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

String? _emptyToNull(String? value) {
  final text = value?.trim();

  if (text == null || text.isEmpty) {
    return null;
  }

  return text;
}
