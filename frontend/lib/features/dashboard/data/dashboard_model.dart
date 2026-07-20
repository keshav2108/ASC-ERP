class DashboardOverview {
  const DashboardOverview({
    required this.summary,
    required this.serviceRequestStatuses,
    required this.jobStatuses,
    required this.revenueLast7Days,
    required this.lowStockParts,
    required this.recentServiceRequests,
    required this.technicianWorkload,
  });

  final DashboardSummary summary;
  final List<StatusCount> serviceRequestStatuses;
  final List<StatusCount> jobStatuses;
  final List<RevenuePoint> revenueLast7Days;
  final List<LowStockPart> lowStockParts;
  final List<RecentServiceRequest> recentServiceRequests;
  final List<TechnicianWorkload> technicianWorkload;

  factory DashboardOverview.fromJson(Map<String, dynamic> json) {
    return DashboardOverview(
      summary: DashboardSummary.fromJson(_asMap(json['summary'])),
      serviceRequestStatuses: _asList(
        json['service_request_statuses'],
      ).map((item) => StatusCount.fromJson(_asMap(item))).toList(),
      jobStatuses: _asList(
        json['job_statuses'],
      ).map((item) => StatusCount.fromJson(_asMap(item))).toList(),
      revenueLast7Days: _asList(
        json['revenue_last_7_days'],
      ).map((item) => RevenuePoint.fromJson(_asMap(item))).toList(),
      lowStockParts: _asList(
        json['low_stock_parts'],
      ).map((item) => LowStockPart.fromJson(_asMap(item))).toList(),
      recentServiceRequests: _asList(
        json['recent_service_requests'],
      ).map((item) => RecentServiceRequest.fromJson(_asMap(item))).toList(),
      technicianWorkload: _asList(
        json['technician_workload'],
      ).map((item) => TechnicianWorkload.fromJson(_asMap(item))).toList(),
    );
  }
}

class DashboardSummary {
  const DashboardSummary({
    required this.totalCustomers,
    required this.totalServiceRequests,
    required this.openServiceRequests,
    required this.activeJobs,
    required this.completedJobs,
    required this.deliveredJobs,
    required this.activeTechnicians,
    required this.techniciansWithActiveJobs,
    required this.lowStockParts,
    required this.unpaidInvoices,
    required this.partiallyPaidInvoices,
    required this.totalRevenue,
  });

  final int totalCustomers;
  final int totalServiceRequests;
  final int openServiceRequests;
  final int activeJobs;
  final int completedJobs;
  final int deliveredJobs;
  final int activeTechnicians;
  final int techniciansWithActiveJobs;
  final int lowStockParts;
  final int unpaidInvoices;
  final int partiallyPaidInvoices;
  final double totalRevenue;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      totalCustomers: _asInt(json['total_customers']),
      totalServiceRequests: _asInt(json['total_service_requests']),
      openServiceRequests: _asInt(json['open_service_requests']),
      activeJobs: _asInt(json['active_jobs']),
      completedJobs: _asInt(json['completed_jobs']),
      deliveredJobs: _asInt(json['delivered_jobs']),
      activeTechnicians: _asInt(json['active_technicians']),
      techniciansWithActiveJobs: _asInt(json['technicians_with_active_jobs']),
      lowStockParts: _asInt(json['low_stock_parts']),
      unpaidInvoices: _asInt(json['unpaid_invoices']),
      partiallyPaidInvoices: _asInt(json['partially_paid_invoices']),
      totalRevenue: _asDouble(json['total_revenue']),
    );
  }
}

class StatusCount {
  const StatusCount({required this.status, required this.count});

  final String status;
  final int count;

  factory StatusCount.fromJson(Map<String, dynamic> json) {
    return StatusCount(
      status: _asString(json['status']),
      count: _asInt(json['count']),
    );
  }
}

class RevenuePoint {
  const RevenuePoint({required this.date, required this.amount});

  final DateTime date;
  final double amount;

  factory RevenuePoint.fromJson(Map<String, dynamic> json) {
    return RevenuePoint(
      date: DateTime.parse(_asString(json['date'])),
      amount: _asDouble(json['amount']),
    );
  }
}

class LowStockPart {
  const LowStockPart({
    required this.id,
    required this.partCode,
    required this.partName,
    required this.brand,
    required this.currentStock,
    required this.minimumStock,
    required this.unit,
  });

  final int id;
  final String partCode;
  final String partName;
  final String? brand;
  final int currentStock;
  final int minimumStock;
  final String unit;

  factory LowStockPart.fromJson(Map<String, dynamic> json) {
    return LowStockPart(
      id: _asInt(json['id']),
      partCode: _asString(json['part_code']),
      partName: _asString(json['part_name']),
      brand: json['brand']?.toString(),
      currentStock: _asInt(json['current_stock']),
      minimumStock: _asInt(json['minimum_stock']),
      unit: _asString(json['unit']),
    );
  }
}

class RecentServiceRequest {
  const RecentServiceRequest({
    required this.id,
    required this.requestCode,
    required this.customerName,
    required this.customerMobile,
    required this.productName,
    required this.brand,
    required this.complaintCategory,
    required this.priority,
    required this.status,
    required this.createdAt,
  });

  final int id;
  final String requestCode;
  final String customerName;
  final String customerMobile;
  final String productName;
  final String brand;
  final String complaintCategory;
  final String priority;
  final String status;
  final DateTime createdAt;

  factory RecentServiceRequest.fromJson(Map<String, dynamic> json) {
    return RecentServiceRequest(
      id: _asInt(json['id']),
      requestCode: _asString(json['request_code']),
      customerName: _asString(json['customer_name']),
      customerMobile: _asString(json['customer_mobile']),
      productName: _asString(json['product_name']),
      brand: _asString(json['brand']),
      complaintCategory: _asString(json['complaint_category']),
      priority: _asString(json['priority']),
      status: _asString(json['status']),
      createdAt: DateTime.parse(_asString(json['created_at'])),
    );
  }
}

class TechnicianWorkload {
  const TechnicianWorkload({
    required this.technicianId,
    required this.technicianCode,
    required this.technicianName,
    required this.availabilityStatus,
    required this.activeJobs,
  });

  final int technicianId;
  final String technicianCode;
  final String technicianName;
  final String availabilityStatus;
  final int activeJobs;

  factory TechnicianWorkload.fromJson(Map<String, dynamic> json) {
    return TechnicianWorkload(
      technicianId: _asInt(json['technician_id']),
      technicianCode: _asString(json['technician_code']),
      technicianName: _asString(json['technician_name']),
      availabilityStatus: _asString(json['availability_status']),
      activeJobs: _asInt(json['active_jobs']),
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

List<dynamic> _asList(dynamic value) {
  if (value is List) {
    return value;
  }

  return <dynamic>[];
}

String _asString(dynamic value) {
  return value?.toString() ?? '';
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
