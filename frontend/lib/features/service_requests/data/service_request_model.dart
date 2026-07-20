class ServiceRequest {
  const ServiceRequest({
    required this.id,
    required this.requestCode,
    required this.customerId,
    required this.customerProductId,
    required this.complaintCategory,
    required this.complaintDescription,
    required this.receivedAccessories,
    required this.productCondition,
    required this.priority,
    required this.status,
    required this.estimatedDelivery,
    required this.createdAt,
    required this.customer,
    required this.customerProduct,
  });

  final int id;
  final String requestCode;
  final int customerId;
  final int customerProductId;
  final String complaintCategory;
  final String complaintDescription;
  final String? receivedAccessories;
  final String productCondition;
  final String priority;
  final String status;
  final DateTime? estimatedDelivery;
  final DateTime createdAt;
  final ServiceRequestCustomer customer;
  final CustomerProduct customerProduct;

  factory ServiceRequest.fromJson(Map<String, dynamic> json) {
    return ServiceRequest(
      id: _asInt(json['id']),
      requestCode: _asString(json['request_code']),
      customerId: _asInt(json['customer_id']),
      customerProductId: _asInt(json['customer_product_id']),
      complaintCategory: _asString(json['complaint_category']),
      complaintDescription: _asString(json['complaint_description']),
      receivedAccessories: _asNullableString(json['received_accessories']),
      productCondition: _asString(json['product_condition']),
      priority: _asString(json['priority']),
      status: _asString(json['status']),
      estimatedDelivery: _asNullableDate(json['estimated_delivery']),
      createdAt: DateTime.parse(_asString(json['created_at'])),
      customer: ServiceRequestCustomer.fromJson(_asMap(json['customer'])),
      customerProduct: CustomerProduct.fromJson(
        _asMap(json['customer_product']),
      ),
    );
  }
}

class ServiceRequestCustomer {
  const ServiceRequestCustomer({
    required this.id,
    required this.customerCode,
    required this.fullName,
    required this.mobile,
  });

  final int id;
  final String customerCode;
  final String fullName;
  final String mobile;

  factory ServiceRequestCustomer.fromJson(Map<String, dynamic> json) {
    return ServiceRequestCustomer(
      id: _asInt(json['id']),
      customerCode: _asString(json['customer_code']),
      fullName: _asString(json['full_name']),
      mobile: _asString(json['mobile']),
    );
  }
}

class CustomerProduct {
  const CustomerProduct({
    required this.id,
    required this.customerId,
    required this.brand,
    required this.productName,
    required this.modelNumber,
    required this.serialNumber,
    required this.purchaseDate,
    required this.warrantyStatus,
    required this.createdAt,
  });

  final int id;
  final int customerId;
  final String brand;
  final String productName;
  final String? modelNumber;
  final String? serialNumber;
  final DateTime? purchaseDate;
  final String warrantyStatus;
  final DateTime? createdAt;

  String get displayName {
    final model = modelNumber;

    if (model == null || model.isEmpty) {
      return '$brand $productName';
    }

    return '$brand $productName — $model';
  }

  factory CustomerProduct.fromJson(Map<String, dynamic> json) {
    return CustomerProduct(
      id: _asInt(json['id']),
      customerId: _asInt(json['customer_id']),
      brand: _asString(json['brand']),
      productName: _asString(json['product_name']),
      modelNumber: _asNullableString(json['model_number']),
      serialNumber: _asNullableString(json['serial_number']),
      purchaseDate: _asNullableDate(json['purchase_date']),
      warrantyStatus: _asString(json['warranty_status']),
      createdAt: _asNullableDate(json['created_at']),
    );
  }
}

class MasterOption {
  const MasterOption({
    required this.id,
    required this.optionType,
    required this.code,
    required this.label,
    required this.displayOrder,
    required this.isActive,
  });

  final int id;
  final String optionType;
  final String code;
  final String label;
  final int displayOrder;
  final bool isActive;

  factory MasterOption.fromJson(Map<String, dynamic> json) {
    return MasterOption(
      id: _asInt(json['id']),
      optionType: _asString(json['option_type']),
      code: _asString(json['code']),
      label: _asString(json['label']),
      displayOrder: _asInt(json['display_order']),
      isActive: json['is_active'] == true,
    );
  }
}

class ServiceRequestCreateInput {
  const ServiceRequestCreateInput({
    required this.customerId,
    required this.customerProductId,
    required this.complaintCategory,
    required this.complaintDescription,
    required this.productCondition,
    required this.priority,
    this.receivedAccessories,
    this.estimatedDelivery,
  });

  final int customerId;
  final int customerProductId;
  final String complaintCategory;
  final String complaintDescription;
  final String? receivedAccessories;
  final String productCondition;
  final String priority;
  final DateTime? estimatedDelivery;

  Map<String, dynamic> toJson() {
    return {
      'customer_id': customerId,
      'customer_product_id': customerProductId,
      'complaint_category': complaintCategory,
      'complaint_description': complaintDescription.trim(),
      'received_accessories': _emptyToNull(receivedAccessories),
      'product_condition': productCondition,
      'priority': priority,
      'estimated_delivery': estimatedDelivery?.toIso8601String(),
    };
  }
}

class ServiceRequestUpdateInput {
  const ServiceRequestUpdateInput({
    this.complaintCategory,
    this.complaintDescription,
    this.receivedAccessories,
    this.productCondition,
    this.priority,
    this.status,
    this.estimatedDelivery,
  });

  final String? complaintCategory;
  final String? complaintDescription;
  final String? receivedAccessories;
  final String? productCondition;
  final String? priority;
  final String? status;
  final DateTime? estimatedDelivery;

  Map<String, dynamic> toJson() {
    return {
      if (complaintCategory != null) 'complaint_category': complaintCategory,
      if (complaintDescription != null)
        'complaint_description': complaintDescription!.trim(),
      if (receivedAccessories != null)
        'received_accessories': _emptyToNull(receivedAccessories),
      if (productCondition != null) 'product_condition': productCondition,
      if (priority != null) 'priority': priority,
      if (status != null) 'status': status,
      if (estimatedDelivery != null)
        'estimated_delivery': estimatedDelivery!.toIso8601String(),
    };
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
