class JobCard {
  const JobCard({
    required this.id,
    required this.jobCode,
    required this.serviceRequestId,
    required this.technicianId,
    required this.diagnosis,
    required this.repairNotes,
    required this.labourCharge,
    required this.status,
    required this.assignedAt,
    required this.startedAt,
    required this.completedAt,
    required this.deliveredAt,
    required this.deliveredTo,
    required this.recipientType,
    required this.receiverName,
    required this.relationToCustomer,
    required this.deliveryRemarks,
    required this.createdAt,
    required this.technician,
    required this.serviceRequest,
  });

  final int id;
  final String jobCode;

  final int serviceRequestId;
  final int technicianId;

  final String? diagnosis;
  final String? repairNotes;

  final double labourCharge;
  final String status;

  final DateTime assignedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  final DateTime? deliveredAt;
  final String? deliveredTo;

  final String? recipientType;
  final String? receiverName;
  final String? relationToCustomer;

  final String? deliveryRemarks;

  final DateTime createdAt;

  final JobCardTechnician technician;
  final JobCardServiceRequest serviceRequest;

  bool get isDelivered => status.toUpperCase() == 'DELIVERED';

  bool get isCancelled => status.toUpperCase() == 'CANCELLED';

  bool get isClosed => isDelivered || isCancelled;

  factory JobCard.fromJson(Map<String, dynamic> json) {
    return JobCard(
      id: _asInt(json['id']),
      jobCode: _asString(json['job_code']),
      serviceRequestId: _asInt(json['service_request_id']),
      technicianId: _asInt(json['technician_id']),
      diagnosis: _asNullableString(json['diagnosis']),
      repairNotes: _asNullableString(json['repair_notes']),
      labourCharge: _asDouble(json['labour_charge']),
      status: _asString(json['status']),
      assignedAt: _asDate(json['assigned_at']),
      startedAt: _asNullableDate(json['started_at']),
      completedAt: _asNullableDate(json['completed_at']),
      deliveredAt: _asNullableDate(json['delivered_at']),
      deliveredTo: _asNullableString(json['delivered_to']),
      recipientType: _asNullableString(json['recipient_type']),
      receiverName: _asNullableString(json['receiver_name']),
      relationToCustomer: _asNullableString(json['relation_to_customer']),
      deliveryRemarks: _asNullableString(json['delivery_remarks']),
      createdAt: _asDate(json['created_at']),
      technician: JobCardTechnician.fromJson(_asMap(json['technician'])),
      serviceRequest: JobCardServiceRequest.fromJson(
        _asMap(json['service_request']),
      ),
    );
  }
}

class JobCardTechnician {
  const JobCardTechnician({
    required this.id,
    required this.technicianCode,
    required this.fullName,
    required this.mobile,
    required this.specialization,
    required this.availabilityStatus,
  });

  final int id;
  final String technicianCode;
  final String fullName;
  final String mobile;
  final String? specialization;
  final String availabilityStatus;

  factory JobCardTechnician.fromJson(Map<String, dynamic> json) {
    return JobCardTechnician(
      id: _asInt(json['id']),
      technicianCode: _asString(json['technician_code']),
      fullName: _asString(json['full_name']),
      mobile: _asString(json['mobile']),
      specialization: _asNullableString(json['specialization']),
      availabilityStatus: _asString(json['availability_status']),
    );
  }
}

class JobCardServiceRequest {
  const JobCardServiceRequest({
    required this.id,
    required this.requestCode,
    required this.complaintCategory,
    required this.complaintDescription,
    required this.priority,
    required this.status,
    required this.customer,
  });

  final int id;
  final String requestCode;
  final String complaintCategory;
  final String complaintDescription;
  final String priority;
  final String status;

  final JobCardCustomer customer;

  factory JobCardServiceRequest.fromJson(Map<String, dynamic> json) {
    return JobCardServiceRequest(
      id: _asInt(json['id']),
      requestCode: _asString(json['request_code']),
      complaintCategory: _asString(json['complaint_category']),
      complaintDescription: _asString(json['complaint_description']),
      priority: _asString(json['priority']),
      status: _asString(json['status']),
      customer: JobCardCustomer.fromJson(_asMap(json['customer'])),
    );
  }
}

class JobCardCustomer {
  const JobCardCustomer({
    required this.id,
    required this.customerCode,
    required this.fullName,
    required this.mobile,
  });

  final int id;
  final String customerCode;
  final String fullName;
  final String mobile;

  factory JobCardCustomer.fromJson(Map<String, dynamic> json) {
    return JobCardCustomer(
      id: _asInt(json['id']),
      customerCode: _asString(json['customer_code']),
      fullName: _asString(json['full_name']),
      mobile: _asString(json['mobile']),
    );
  }
}

class JobCardUpdateInput {
  const JobCardUpdateInput({
    this.technicianId,
    this.diagnosis,
    this.repairNotes,
    this.labourCharge,
    this.includeDiagnosis = false,
    this.includeRepairNotes = false,
  });

  final int? technicianId;
  final String? diagnosis;
  final String? repairNotes;
  final double? labourCharge;

  final bool includeDiagnosis;
  final bool includeRepairNotes;

  Map<String, dynamic> toJson() {
    return {
      if (technicianId != null) 'technician_id': technicianId,
      if (includeDiagnosis) 'diagnosis': _emptyToNull(diagnosis),
      if (includeRepairNotes) 'repair_notes': _emptyToNull(repairNotes),
      if (labourCharge != null) 'labour_charge': labourCharge,
    };
  }
}

class TechnicianAssignmentInput {
  const TechnicianAssignmentInput({
    required this.technicianId,
    this.diagnosis,
    this.repairNotes,
    this.labourCharge = 0,
  });

  final int technicianId;
  final String? diagnosis;
  final String? repairNotes;
  final double labourCharge;

  Map<String, dynamic> toJson() {
    return {
      'technician_id': technicianId,
      'diagnosis': _emptyToNull(diagnosis),
      'repair_notes': _emptyToNull(repairNotes),
      'labour_charge': labourCharge,
    };
  }
}

class JobCardDeliveryInput {
  const JobCardDeliveryInput({
    required this.recipientType,
    this.receiverName,
    this.relationToCustomer,
    this.deliveryRemarks,
  });

  final String recipientType;
  final String? receiverName;
  final String? relationToCustomer;

  final String? deliveryRemarks;

  Map<String, dynamic> toJson() {
    return {
      'recipient_type': recipientType.trim().toUpperCase(),
      'receiver_name': _emptyToNull(receiverName),
      'relation_to_customer': _emptyToNull(relationToCustomer),
      'remarks': _emptyToNull(deliveryRemarks),
    };
  }
}

class WorkflowTransition {
  const WorkflowTransition({
    required this.id,
    required this.fromStatus,
    required this.toStatus,
    required this.action,
    required this.isActive,
  });

  final int id;
  final String fromStatus;
  final String toStatus;
  final String action;
  final bool isActive;

  factory WorkflowTransition.fromJson(Map<String, dynamic> json) {
    return WorkflowTransition(
      id: _asInt(json['id']),
      fromStatus: _asString(json['from_status']),
      toStatus: _asString(json['to_status']),
      action: _asString(json['action']),
      isActive: json['is_active'] == true,
    );
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }

  return <String, dynamic>{};
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

double _asDouble(dynamic value) {
  if (value is double) {
    return value;
  }

  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime _asDate(dynamic value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');

  return parsed ?? DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime? _asNullableDate(dynamic value) {
  final text = value?.toString().trim();

  if (text == null || text.isEmpty) {
    return null;
  }

  return DateTime.tryParse(text);
}

String? _emptyToNull(String? value) {
  final text = value?.trim();

  if (text == null || text.isEmpty) {
    return null;
  }

  return text;
}
