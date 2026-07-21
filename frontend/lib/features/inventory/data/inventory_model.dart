double _parseDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value?.toString().trim() ?? '') ?? 0;
}

int _parseInt(Object? value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString().trim() ?? '') ?? 0;
}

bool _parseBool(Object? value) {
  if (value is bool) {
    return value;
  }

  if (value is num) {
    return value != 0;
  }

  final normalizedValue = value?.toString().trim().toLowerCase();

  return normalizedValue == 'true' ||
      normalizedValue == '1' ||
      normalizedValue == 'yes';
}

DateTime _parseDateTime(Object? value) {
  return DateTime.tryParse(value?.toString() ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

String? _nullableString(Object? value) {
  final text = value?.toString().trim();

  if (text == null || text.isEmpty) {
    return null;
  }

  return text;
}

String? _cleanOptionalText(String? value) {
  final text = value?.trim();

  if (text == null || text.isEmpty) {
    return null;
  }

  return text;
}

Map<String, dynamic> _parseMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }

  return const <String, dynamic>{};
}

class InventoryTransactionTypes {
  InventoryTransactionTypes._();

  static const String stockIn = 'STOCK_IN';
  static const String issue = 'ISSUE';
  static const String stockReturn = 'RETURN';
  static const String adjustment = 'ADJUSTMENT';

  static const Set<String> values = <String>{
    stockIn,
    issue,
    stockReturn,
    adjustment,
  };

  static String normalize(Object? value) {
    return value
            ?.toString()
            .trim()
            .toUpperCase()
            .replaceAll('-', '_')
            .replaceAll(' ', '_') ??
        '';
  }
}

class SparePart {
  const SparePart({
    required this.id,
    required this.partCode,
    required this.partName,
    required this.unit,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.currentStock,
    required this.minimumStock,
    required this.isActive,
    required this.createdAt,
    this.brand,
    this.productCategory,
  });

  factory SparePart.fromJson(Map<String, dynamic> json) {
    return SparePart(
      id: _parseInt(json['id']),
      partCode: json['part_code']?.toString() ?? '',
      partName: json['part_name']?.toString() ?? '',
      brand: _nullableString(json['brand']),
      productCategory: _nullableString(json['product_category']),
      unit: json['unit']?.toString() ?? 'PIECE',
      purchasePrice: _parseDouble(json['purchase_price']),
      sellingPrice: _parseDouble(json['selling_price']),
      currentStock: _parseInt(json['current_stock']),
      minimumStock: _parseInt(json['minimum_stock']),
      isActive: _parseBool(json['is_active']),
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  final int id;
  final String partCode;
  final String partName;
  final String? brand;
  final String? productCategory;
  final String unit;
  final double purchasePrice;
  final double sellingPrice;
  final int currentStock;
  final int minimumStock;
  final bool isActive;
  final DateTime createdAt;

  bool get isOutOfStock {
    return currentStock <= 0;
  }

  bool get isLowStock {
    return currentStock <= minimumStock;
  }

  bool get hasAvailableStock {
    return currentStock > 0;
  }

  double get currentPurchaseValue {
    return purchasePrice * currentStock;
  }

  double get currentSellingValue {
    return sellingPrice * currentStock;
  }

  double get expectedMarginPerUnit {
    return sellingPrice - purchasePrice;
  }

  String get displayBrand {
    return brand ?? 'Unbranded';
  }

  String get displayCategory {
    return productCategory ?? 'General';
  }

  String get normalizedUnit {
    return unit.trim().toUpperCase();
  }

  SparePart copyWith({
    int? id,
    String? partCode,
    String? partName,
    String? brand,
    String? productCategory,
    String? unit,
    double? purchasePrice,
    double? sellingPrice,
    int? currentStock,
    int? minimumStock,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return SparePart(
      id: id ?? this.id,
      partCode: partCode ?? this.partCode,
      partName: partName ?? this.partName,
      brand: brand ?? this.brand,
      productCategory: productCategory ?? this.productCategory,
      unit: unit ?? this.unit,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      currentStock: currentStock ?? this.currentStock,
      minimumStock: minimumStock ?? this.minimumStock,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class StockTransaction {
  const StockTransaction({
    required this.id,
    required this.sparePartId,
    required this.transactionType,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.createdAt,
    required this.sparePart,
    this.jobCardId,
    this.reference,
    this.remarks,
  });

  factory StockTransaction.fromJson(Map<String, dynamic> json) {
    return StockTransaction(
      id: _parseInt(json['id']),
      sparePartId: _parseInt(json['spare_part_id']),
      jobCardId: json['job_card_id'] == null
          ? null
          : _parseInt(json['job_card_id']),
      transactionType: InventoryTransactionTypes.normalize(
        json['transaction_type'],
      ),
      quantity: _parseInt(json['quantity']),
      unitPrice: _parseDouble(json['unit_price']),
      lineTotal: _parseDouble(json['line_total']),
      reference: _nullableString(json['reference']),
      remarks: _nullableString(json['remarks']),
      createdAt: _parseDateTime(json['created_at']),
      sparePart: SparePart.fromJson(_parseMap(json['spare_part'])),
    );
  }

  final int id;
  final int sparePartId;
  final int? jobCardId;
  final String transactionType;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
  final String? reference;
  final String? remarks;
  final DateTime createdAt;
  final SparePart sparePart;

  bool get isStockIn {
    return transactionType == InventoryTransactionTypes.stockIn;
  }

  bool get isIssue {
    return transactionType == InventoryTransactionTypes.issue;
  }

  bool get isReturn {
    return transactionType == InventoryTransactionTypes.stockReturn;
  }

  bool get isAdjustment {
    return transactionType == InventoryTransactionTypes.adjustment;
  }

  bool get isJobCardTransaction {
    return jobCardId != null;
  }

  bool get increasesStock {
    if (isStockIn || isReturn) {
      return true;
    }

    if (isAdjustment) {
      return quantity > 0;
    }

    return false;
  }

  bool get decreasesStock {
    if (isIssue) {
      return true;
    }

    if (isAdjustment) {
      return quantity < 0;
    }

    return false;
  }

  int get signedQuantity {
    if (isIssue) {
      return -quantity.abs();
    }

    return quantity;
  }

  String get displayReference {
    return reference ?? '—';
  }

  String get displayRemarks {
    return remarks ?? 'No remarks';
  }
}

class SparePartCreateInput {
  const SparePartCreateInput({
    required this.partName,
    required this.unit,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.currentStock,
    required this.minimumStock,
    this.brand,
    this.productCategory,
  });

  final String partName;
  final String? brand;
  final String? productCategory;
  final String unit;
  final double purchasePrice;
  final double sellingPrice;
  final int currentStock;
  final int minimumStock;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'part_name': partName.trim(),
      'brand': _cleanOptionalText(brand),
      'product_category': _cleanOptionalText(productCategory),
      'unit': unit.trim().toUpperCase(),
      'purchase_price': purchasePrice,
      'selling_price': sellingPrice,
      'current_stock': currentStock,
      'minimum_stock': minimumStock,
    };
  }
}

class SparePartUpdateInput {
  const SparePartUpdateInput({
    this.partName,
    this.brand,
    this.productCategory,
    this.unit,
    this.purchasePrice,
    this.sellingPrice,
    this.minimumStock,
    this.isActive,
    this.includeBrand = false,
    this.includeProductCategory = false,
  });

  final String? partName;
  final String? brand;
  final String? productCategory;
  final String? unit;
  final double? purchasePrice;
  final double? sellingPrice;
  final int? minimumStock;
  final bool? isActive;

  final bool includeBrand;
  final bool includeProductCategory;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    if (partName != null) {
      json['part_name'] = partName!.trim();
    }

    if (includeBrand) {
      json['brand'] = _cleanOptionalText(brand);
    }

    if (includeProductCategory) {
      json['product_category'] = _cleanOptionalText(productCategory);
    }

    if (unit != null) {
      json['unit'] = unit!.trim().toUpperCase();
    }

    if (purchasePrice != null) {
      json['purchase_price'] = purchasePrice;
    }

    if (sellingPrice != null) {
      json['selling_price'] = sellingPrice;
    }

    if (minimumStock != null) {
      json['minimum_stock'] = minimumStock;
    }

    if (isActive != null) {
      json['is_active'] = isActive;
    }

    return json;
  }
}

class StockInInput {
  const StockInInput({
    required this.sparePartId,
    required this.quantity,
    this.reference,
    this.remarks,
  });

  final int sparePartId;
  final int quantity;
  final String? reference;
  final String? remarks;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'spare_part_id': sparePartId,
      'quantity': quantity,
      'reference': _cleanOptionalText(reference),
      'remarks': _cleanOptionalText(remarks),
    };
  }
}

class StockIssueInput {
  const StockIssueInput({
    required this.sparePartId,
    required this.jobCardId,
    required this.quantity,
    this.remarks,
  });

  final int sparePartId;
  final int jobCardId;
  final int quantity;
  final String? remarks;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'spare_part_id': sparePartId,
      'job_card_id': jobCardId,
      'quantity': quantity,
      'remarks': _cleanOptionalText(remarks),
    };
  }
}

class StockReturnInput {
  const StockReturnInput({
    required this.sparePartId,
    required this.jobCardId,
    required this.quantity,
    this.remarks,
  });

  final int sparePartId;
  final int jobCardId;
  final int quantity;
  final String? remarks;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'spare_part_id': sparePartId,
      'job_card_id': jobCardId,
      'quantity': quantity,
      'remarks': _cleanOptionalText(remarks),
    };
  }
}

class StockAdjustmentInput {
  const StockAdjustmentInput({
    required this.sparePartId,
    required this.newQuantity,
    required this.remarks,
  });

  final int sparePartId;
  final int newQuantity;
  final String remarks;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'spare_part_id': sparePartId,
      'new_quantity': newQuantity,
      'remarks': remarks.trim(),
    };
  }
}
