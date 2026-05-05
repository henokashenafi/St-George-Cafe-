class TableZone {
  final int? id;
  final String name;
  final int? waiterId;
  final String? waiterName; // convenience

  TableZone({
    this.id,
    required this.name,
    this.waiterId,
    this.waiterName,
  });

  factory TableZone.fromMap(Map<String, dynamic> map) {
    return TableZone(
      id: map['id'],
      name: map['name'],
      waiterId: map['waiter_id'],
      waiterName: map['waiter_name'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'waiter_id': waiterId,
    };
  }
}
