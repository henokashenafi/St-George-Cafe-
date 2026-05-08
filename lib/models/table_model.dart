enum TableStatus { available, occupied, reserved }

class TableModel {
  final int? id;
  final String name;
  final TableStatus status;
  final int? zoneId;
  final String? zoneName; // convenience
  final int? waiterId; // assigned waiter based on zone
  final String? waiterName; // convenience

  TableModel({
    this.id,
    required this.name,
    this.status = TableStatus.available,
    this.zoneId,
    this.zoneName,
    this.waiterId,
    this.waiterName,
  });

  factory TableModel.fromMap(Map<String, dynamic> map) {
    return TableModel(
      id: map['id'],
      name: map['name'],
      status: TableStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => TableStatus.available,
      ),
      zoneId: map['zone_id'],
      zoneName: map['zone_name'],
      waiterId: map['waiter_id'],
      waiterName: map['waiter_name'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'status': status.toString().split('.').last,
      'zone_id': zoneId,
      'waiter_id': waiterId,
    };
  }

  TableModel copyWith({
    int? id,
    String? name,
    TableStatus? status,
    int? zoneId,
    String? zoneName,
    int? waiterId,
    String? waiterName,
  }) {
    return TableModel(
      id: id ?? this.id,
      name: name ?? this.name,
      status: status ?? this.status,
      zoneId: zoneId ?? this.zoneId,
      zoneName: zoneName ?? this.zoneName,
      waiterId: waiterId ?? this.waiterId,
      waiterName: waiterName ?? this.waiterName,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TableModel &&
        other.id == id &&
        other.name == name &&
        other.status == status &&
        other.zoneId == zoneId;
  }

  @override
  int get hashCode {
    return id.hashCode ^ name.hashCode ^ status.hashCode ^ zoneId.hashCode;
  }

  @override
  String toString() {
    return 'TableModel(id: $id, name: $name, status: $status, zoneId: $zoneId, waiterId: $waiterId)';
  }
}
