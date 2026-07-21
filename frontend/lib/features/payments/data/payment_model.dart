class Payment {
  const Payment({
    required this.id,
    required this.paymentCode,
    required this.invoiceId,
    required this.amount,
    required this.paymentMethod,
    required this.status,
    required this.paidAt,
    required this.createdAt,
    this.transactionReference,
    this.remarks,
  });

  final int id;
  final String paymentCode;
  final int invoiceId;
  final double amount;
  final String paymentMethod;
  final String? transactionReference;
  final String? remarks;
  final String status;
  final DateTime paidAt;
  final DateTime createdAt;

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: _asInt(json['id']),
      paymentCode: _asString(json['payment_code']),
      invoiceId: _asInt(json['invoice_id']),
      amount: _asDouble(json['amount']),
      paymentMethod: _asString(json['payment_method']),
      transactionReference: _asNullableString(json['transaction_reference']),
      remarks: _asNullableString(json['remarks']),
      status: _asString(json['status']),
      paidAt: _asDateTime(json['paid_at']),
      createdAt: _asDateTime(json['created_at']),
    );
  }

  bool get isSuccessful {
    return status.trim().toUpperCase() == 'SUCCESS';
  }

  bool get isCancelled {
    return status.trim().toUpperCase() == 'CANCELLED';
  }

  String get formattedMethod {
    return paymentMethod
        .trim()
        .toLowerCase()
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}

class PaymentCreateInput {
  const PaymentCreateInput({
    required this.invoiceId,
    required this.amount,
    required this.paymentMethod,
    this.transactionReference,
    this.remarks,
  });

  final int invoiceId;
  final double amount;
  final String paymentMethod;
  final String? transactionReference;
  final String? remarks;

  Map<String, dynamic> toJson() {
    final normalizedReference = transactionReference?.trim();
    final normalizedRemarks = remarks?.trim();

    return {
      'invoice_id': invoiceId,
      'amount': amount,
      'payment_method': paymentMethod.trim().toUpperCase().replaceAll(' ', '_'),
      'transaction_reference':
          normalizedReference == null || normalizedReference.isEmpty
          ? null
          : normalizedReference,
      'remarks': normalizedRemarks == null || normalizedRemarks.isEmpty
          ? null
          : normalizedRemarks,
    };
  }
}

class InvoicePaymentSummary {
  const InvoicePaymentSummary({
    required this.invoiceId,
    required this.invoiceCode,
    required this.totalAmount,
    required this.paidAmount,
    required this.balanceAmount,
    required this.paymentStatus,
    required this.payments,
  });

  final int invoiceId;
  final String invoiceCode;
  final double totalAmount;
  final double paidAmount;
  final double balanceAmount;
  final String paymentStatus;
  final List<Payment> payments;

  factory InvoicePaymentSummary.fromJson(Map<String, dynamic> json) {
    final paymentList = json['payments'];

    return InvoicePaymentSummary(
      invoiceId: _asInt(json['invoice_id']),
      invoiceCode: _asString(json['invoice_code']),
      totalAmount: _asDouble(json['total_amount']),
      paidAmount: _asDouble(json['paid_amount']),
      balanceAmount: _asDouble(json['balance_amount']),
      paymentStatus: _asString(json['payment_status']),
      payments: paymentList is List
          ? paymentList
                .whereType<Map>()
                .map(
                  (payment) =>
                      Payment.fromJson(Map<String, dynamic>.from(payment)),
                )
                .toList()
          : const <Payment>[],
    );
  }

  bool get isPaid {
    return paymentStatus.trim().toUpperCase() == 'PAID';
  }

  bool get isPartiallyPaid {
    return paymentStatus.trim().toUpperCase() == 'PARTIALLY_PAID';
  }

  bool get isUnpaid {
    return paymentStatus.trim().toUpperCase() == 'UNPAID';
  }

  double get paymentProgress {
    if (totalAmount <= 0) {
      return 0;
    }

    return (paidAmount / totalAmount).clamp(0.0, 1.0);
  }
}

const List<String> supportedPaymentMethods = <String>[
  'CASH',
  'UPI',
  'CARD',
  'BANK_TRANSFER',
];

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _asDouble(Object? value) {
  if (value is double) {
    return value;
  }

  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value?.toString() ?? '') ?? 0;
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

  final parsed = DateTime.tryParse(value?.toString().trim() ?? '');

  return parsed ?? DateTime.fromMillisecondsSinceEpoch(0);
}
