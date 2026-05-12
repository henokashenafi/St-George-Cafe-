class CafeSettings {
  final String name;
  final String address;
  final String phone;
  final String vatNumber;
  final double vatRate;
  final String currency;

  final String defaultPrinterName;

  CafeSettings({
    this.name = 'ST GEORGE CAFE',
    this.address = 'Addis Ababa, Ethiopia',
    this.phone = '+251 911 000000',
    this.vatNumber = '1234567890',
    this.vatRate = 5.0,
    this.currency = 'ETB',
    this.defaultPrinterName = '',
  });

  CafeSettings copyWith({
    String? name,
    String? address,
    String? phone,
    String? vatNumber,
    double? vatRate,
    String? currency,
    String? defaultPrinterName,
  }) {
    return CafeSettings(
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      vatNumber: vatNumber ?? this.vatNumber,
      vatRate: vatRate ?? this.vatRate,
      currency: currency ?? this.currency,
      defaultPrinterName: defaultPrinterName ?? this.defaultPrinterName,
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
      'default_printer_name': defaultPrinterName,
    };
  }

  factory CafeSettings.fromMap(Map<String, dynamic> map) {
    return CafeSettings(
      name: map['name'] ?? 'ST GEORGE CAFE',
      address: map['address'] ?? 'Addis Ababa, Ethiopia',
      phone: map['phone'] ?? '+251 911 000000',
      vatNumber: map['vatNumber'] ?? '1234567890',
      vatRate: (map['vatRate'] ?? 5.0).toDouble(),
      currency: map['currency'] ?? 'ETB',
      defaultPrinterName: map['default_printer_name'] ?? '',
    );
  }
}
