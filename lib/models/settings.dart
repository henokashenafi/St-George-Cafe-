class CafeSettings {
  final String name;
  final String address;
  final String phone;
  final String vatNumber;
  final double vatRate;
  final String currency;

  CafeSettings({
    this.name = 'ST GEORGE CAFE',
    this.address = 'Bahir Dar, Ethiopia. behind ST George Church',
    this.phone = '+251 911 000000',
    this.vatNumber = '1234567890',
    this.vatRate = 5.0,
    this.currency = 'ETB',
  });

  CafeSettings copyWith({
    String? name,
    String? address,
    String? phone,
    String? vatNumber,
    double? vatRate,
    String? currency,
  }) {
    return CafeSettings(
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      vatNumber: vatNumber ?? this.vatNumber,
      vatRate: vatRate ?? this.vatRate,
      currency: currency ?? this.currency,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'phone': phone,
      'vatNumber': vatNumber,
      'vatRate': vatRate,
      'currency': currency,
    };
  }

  factory CafeSettings.fromMap(Map<String, dynamic> map) {
    return CafeSettings(
      name: map['name'] ?? 'ST GEORGE CAFE',
      address: map['address'] ?? 'Bahir Dar, Ethiopia. behind ST George Church',
      phone: map['phone'] ?? '+251 911 000000',
      vatNumber: map['vatNumber'] ?? '1234567890',
      vatRate: (map['vatRate'] ?? 5.0).toDouble(),
      currency: map['currency'] ?? 'ETB',
    );
  }
}
