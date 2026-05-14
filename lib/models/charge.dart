class ChargeModel {
  final int? id;
  final String name;
  final String? nameAmharic;
  final String type; // 'addition' or 'deduction'
  final double value; // percentage
  final bool isActive;

  ChargeModel({
    this.id,
    required this.name,
    this.nameAmharic,
    required this.type,
    required this.value,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'name_amharic': nameAmharic,
      'type': type,
      'value': value,
      'is_active': isActive ? 1 : 0,
    };
  }

  factory ChargeModel.fromMap(Map<String, dynamic> map) {
    return ChargeModel(
      id: map['id'],
      name: map['name'] ?? 'Unknown Charge',
      nameAmharic: map['name_amharic'],
      type: map['type'] ?? 'addition',
      value: (map['value'] as num? ?? 0).toDouble(),
      isActive: (map['is_active'] ?? 1) == 1,
    );
  }

  ChargeModel copyWith({
    int? id,
    String? name,
    String? nameAmharic,
    String? type,
    double? value,
    bool? isActive,
  }) {
    return ChargeModel(
      id: id ?? this.id,
      name: name ?? this.name,
      nameAmharic: nameAmharic ?? this.nameAmharic,
      type: type ?? this.type,
      value: value ?? this.value,
      isActive: isActive ?? this.isActive,
    );
  }
}
