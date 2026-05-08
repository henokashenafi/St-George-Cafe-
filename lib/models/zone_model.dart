import 'table_model.dart';

class Zone {
  final int? id;
  final String name;
  final int? waiterId;
  final String? waiterName;
  final List<TableModel> tables;

  Zone({
    this.id,
    required this.name,
    this.waiterId,
    this.waiterName,
    this.tables = const [],
  });

  factory Zone.fromMap(Map<String, dynamic> map) {
    return Zone(
      id: map['id'],
      name: map['name'],
      waiterId: map['waiter_id'],
      waiterName: map['waiter_name'],
      tables: (map['tables'] as List<dynamic>?)
              ?.map((table) => TableModel.fromMap(table as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'waiter_id': waiterId,
      'waiter_name': waiterName,
      'tables': tables.map((table) => table.toMap()).toList(),
    };
  }

  Zone copyWith({
    int? id,
    String? name,
    int? waiterId,
    String? waiterName,
    List<TableModel>? tables,
  }) {
    return Zone(
      id: id ?? this.id,
      name: name ?? this.name,
      waiterId: waiterId ?? this.waiterId,
      waiterName: waiterName ?? this.waiterName,
      tables: tables ?? this.tables,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Zone &&
        other.id == id &&
        other.name == name &&
        other.waiterId == waiterId;
  }

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ waiterId.hashCode;

  @override
  String toString() =>
      'Zone(id: $id, name: $name, waiterId: $waiterId, tables: ${tables.length})';
}
