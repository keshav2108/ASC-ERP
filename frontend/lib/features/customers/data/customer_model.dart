class Customer {
  const Customer({
    required this.id,
    required this.customerCode,
    required this.fullName,
    required this.mobile,
    required this.alternateMobile,
    required this.email,
    required this.address,
    required this.city,
    required this.pincode,
    required this.status,
    required this.createdAt,
  });

  final int id;
  final String customerCode;
  final String fullName;
  final String mobile;
  final String? alternateMobile;
  final String? email;
  final String? address;
  final String? city;
  final String? pincode;
  final String status;
  final DateTime createdAt;

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: _asInt(json['id']),
      customerCode: _asString(json['customer_code']),
      fullName: _asString(json['full_name']),
      mobile: _asString(json['mobile']),
      alternateMobile: _asNullableString(json['alternate_mobile']),
      email: _asNullableString(json['email']),
      address: _asNullableString(json['address']),
      city: _asNullableString(json['city']),
      pincode: _asNullableString(json['pincode']),
      status: _asString(json['status']),
      createdAt: DateTime.parse(_asString(json['created_at'])),
    );
  }
}

class CustomerInput {
  const CustomerInput({
    required this.fullName,
    required this.mobile,
    this.alternateMobile,
    this.email,
    this.address,
    this.city,
    this.pincode,
  });

  final String fullName;
  final String mobile;
  final String? alternateMobile;
  final String? email;
  final String? address;
  final String? city;
  final String? pincode;

  Map<String, dynamic> toJson() {
    return {
      'full_name': fullName.trim(),
      'mobile': mobile.trim(),
      'alternate_mobile': _emptyToNull(alternateMobile),
      'email': _emptyToNull(email),
      'address': _emptyToNull(address),
      'city': _emptyToNull(city),
      'pincode': _emptyToNull(pincode),
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

String? _emptyToNull(String? value) {
  final text = value?.trim();

  if (text == null || text.isEmpty) {
    return null;
  }

  return text;
}
