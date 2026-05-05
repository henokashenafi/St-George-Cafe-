enum TableStatus { available, occupied, reserved }

class TableModel {
  final int? id;
  final String name;
  final TableStatus status;
  final int? zoneId;
  final String? zoneName; // convenience

  TableModel({
    this.id,
    required this.name,
    this.status = TableStatus.available,
    this.zoneId,
    this.zoneName,
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
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'status': status.toString().split('.').last,
      'zone_id': zoneId,
    };
  }
}
