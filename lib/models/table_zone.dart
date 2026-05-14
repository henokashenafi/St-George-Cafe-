class TableZone {
  final int? id;
  final String name;
  final String? nameAmharic;
  final int? waiterId;
  final String? waiterName; // convenience

  TableZone({
    this.id,
    required this.name,
    this.nameAmharic,
    this.waiterId,
    this.waiterName,
  });

  factory TableZone.fromMap(Map<String, dynamic> map) {
    return TableZone(
      id: map['id'],
      name: map['name'],
      nameAmharic: map['name_amharic'],
      waiterId: map['waiter_id'],
      waiterName: map['waiter_name'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'name_amharic': nameAmharic,
      'waiter_id': waiterId,
    };
  }
}
