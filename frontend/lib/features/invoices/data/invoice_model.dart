class Invoice {
  const Invoice({
    required this.id,
    required this.invoiceCode,
    required this.jobCardId,
    required this.customerId,
    required this.labourAmount,
    required this.partsAmount,
    required this.subtotal,
    required this.discountAmount,
    required this.taxableAmount,
    required this.gstPercentage,
    required this.gstAmount,
    required this.totalAmount,
    required this.paymentStatus,
    required this.status,
    required this.createdAt,
    required this.customer,
    required this.jobCard,
    required this.items,
  });

  final int id;
  final String invoiceCode;

  final int jobCardId;
  final int customerId;

  final double labourAmount;
  final double partsAmount;
  final double subtotal;
  final double discountAmount;
  final double taxableAmount;
  final double gstPercentage;
  final double gstAmount;
  final double totalAmount;

  final String paymentStatus;
  final String status;

  final DateTime createdAt;

  final InvoiceCustomer customer;
  final InvoiceJobCard jobCard;
  final List<InvoiceItem> items;

  bool get isCancelled {
    return status.trim().toUpperCase() == 'CANCELLED';
  }

  bool get isPaid {
    return paymentStatus.trim().toUpperCase() == 'PAID';
  }

  bool get isPartiallyPaid {
    return paymentStatus.trim().toUpperCase() == 'PARTIALLY_PAID';
  }

  bool get canAcceptPayment {
    return !isCancelled && !isPaid;
  }

  double get partsAndLabourTotal {
    return labourAmount + partsAmount;
  }

  factory Invoice.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];

    return Invoice(
      id: _asInt(json['id']),
      invoiceCode: _asString(json['invoice_code']),
      jobCardId: _asInt(json['job_card_id']),
      customerId: _asInt(json['customer_id']),
      labourAmount: _asDouble(json['labour_amount']),
      partsAmount: _asDouble(json['parts_amount']),
      subtotal: _asDouble(json['subtotal']),
      discountAmount: _asDouble(json['discount_amount']),
      taxableAmount: _asDouble(json['taxable_amount']),
      gstPercentage: _asDouble(json['gst_percentage']),
      gstAmount: _asDouble(json['gst_amount']),
      totalAmount: _asDouble(json['total_amount']),
      paymentStatus: _asString(json['payment_status']),
      status: _asString(json['status']),
      createdAt: _asDate(json['created_at']),
      customer: InvoiceCustomer.fromJson(_asMap(json['customer'])),
      jobCard: InvoiceJobCard.fromJson(_asMap(json['job_card'])),
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map(
                  (item) =>
                      InvoiceItem.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList(growable: false)
          : const <InvoiceItem>[],
    );
  }
}

class InvoiceItem {
  const InvoiceItem({
    required this.id,
    required this.invoiceId,
    required this.sparePartId,
    required this.itemType,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  final int id;
  final int invoiceId;
  final int? sparePartId;

  final String itemType;
  final String description;

  final int quantity;
  final double unitPrice;
  final double totalPrice;

  bool get isLabour {
    return itemType.trim().toUpperCase() == 'LABOUR';
  }

  bool get isSparePart {
    return itemType.trim().toUpperCase() == 'SPARE_PART';
  }

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    return InvoiceItem(
      id: _asInt(json['id']),
      invoiceId: _asInt(json['invoice_id']),
      sparePartId: _asNullableInt(json['spare_part_id']),
      itemType: _asString(json['item_type']),
      description: _asString(json['description']),
      quantity: _asInt(json['quantity']),
      unitPrice: _asDouble(json['unit_price']),
      totalPrice: _asDouble(json['total_price']),
    );
  }
}

class InvoiceCustomer {
  const InvoiceCustomer({
    required this.id,
    required this.customerCode,
    required this.fullName,
    required this.mobile,
    required this.email,
    required this.address,
    required this.city,
    required this.pincode,
  });

  final int id;
  final String customerCode;
  final String fullName;
  final String mobile;

  final String? email;
  final String? address;
  final String? city;
  final String? pincode;

  String get formattedAddress {
    final parts = <String>[
      if (address != null && address!.trim().isNotEmpty) address!.trim(),
      if (city != null && city!.trim().isNotEmpty) city!.trim(),
      if (pincode != null && pincode!.trim().isNotEmpty) pincode!.trim(),
    ];

    return parts.join(', ');
  }

  factory InvoiceCustomer.fromJson(Map<String, dynamic> json) {
    return InvoiceCustomer(
      id: _asInt(json['id']),
      customerCode: _asString(json['customer_code']),
      fullName: _asString(json['full_name']),
      mobile: _asString(json['mobile']),
      email: _asNullableString(json['email']),
      address: _asNullableString(json['address']),
      city: _asNullableString(json['city']),
      pincode: _asNullableString(json['pincode']),
    );
  }
}

class InvoiceJobCard {
  const InvoiceJobCard({
    required this.id,
    required this.jobCode,
    required this.serviceRequestId,
    required this.technicianId,
    required this.diagnosis,
    required this.repairNotes,
    required this.labourCharge,
    required this.status,
  });

  final int id;
  final String jobCode;

  final int serviceRequestId;
  final int technicianId;

  final String? diagnosis;
  final String? repairNotes;

  final double labourCharge;
  final String status;

  factory InvoiceJobCard.fromJson(Map<String, dynamic> json) {
    return InvoiceJobCard(
      id: _asInt(json['id']),
      jobCode: _asString(json['job_code']),
      serviceRequestId: _asInt(json['service_request_id']),
      technicianId: _asInt(json['technician_id']),
      diagnosis: _asNullableString(json['diagnosis']),
      repairNotes: _asNullableString(json['repair_notes']),
      labourCharge: _asDouble(json['labour_charge']),
      status: _asString(json['status']),
    );
  }
}

class InvoiceCreateInput {
  const InvoiceCreateInput({
    required this.jobCardId,
    this.discountAmount = 0,
    this.gstPercentage = 0,
  });

  final int jobCardId;
  final double discountAmount;
  final double gstPercentage;

  Map<String, dynamic> toJson() {
    return {
      'job_card_id': jobCardId,
      'discount_amount': discountAmount,
      'gst_percentage': gstPercentage,
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
  return DateTime.tryParse(value?.toString() ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0);
}
