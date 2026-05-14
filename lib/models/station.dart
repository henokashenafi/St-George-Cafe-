class Station {
  final int? id;
  final String name;
  final String? nameAmharic;
  final String? printerName;

  Station({
    this.id,
    required this.name,
    this.nameAmharic,
    this.printerName,
  });

  Station copyWith({
    int? id,
    String? name,
    String? nameAmharic,
    String? printerName,
  }) {
    return Station(
      id: id ?? this.id,
      name: name ?? this.name,
      nameAmharic: nameAmharic ?? this.nameAmharic,
      printerName: printerName ?? this.printerName,
    );
  }

  factory Station.fromMap(Map<String, dynamic> map) {
    return Station(
      id: map['id'],
      name: map['name'] ?? '',
      nameAmharic: map['name_amharic'],
      printerName: map['printer_name'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'name_amharic': nameAmharic,
      'printer_name': printerName,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Station &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;
}
