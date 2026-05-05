enum TableStatus { available, occupied, reserved }

class TableModel {
  final int? id;
  final String name;
  final TableStatus status;

  TableModel({
    this.id,
    required this.name,
    this.status = TableStatus.available,
  });

  factory TableModel.fromMap(Map<String, dynamic> map) {
    return TableModel(
      id: map['id'],
      name: map['name'],
      status: TableStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => TableStatus.available,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'status': status.toString().split('.').last,
    };
  }
}
