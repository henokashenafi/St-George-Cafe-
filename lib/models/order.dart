import 'package:st_george_pos/models/order_item.dart';

enum OrderStatus { pending, completed, cancelled }

class OrderModel {
  final int? id;
  final int tableId;
  final int waiterId;
  final String tableName; // Convenience
  final String waiterName; // Convenience
  final OrderStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double totalAmount;
  final List<OrderItem> items;

  OrderModel({
    this.id,
    required this.tableId,
    required this.waiterId,
    required this.tableName,
    required this.waiterName,
    this.status = OrderStatus.pending,
    required this.createdAt,
    required this.updatedAt,
    this.totalAmount = 0.0,
    this.items = const [],
  });

  OrderModel copyWith({
    int? id,
    OrderStatus? status,
    DateTime? updatedAt,
    double? totalAmount,
    List<OrderItem>? items,
  }) {
    return OrderModel(
      id: id ?? this.id,
      tableId: this.tableId,
      waiterId: this.waiterId,
      tableName: this.tableName,
      waiterName: this.waiterName,
      status: status ?? this.status,
      createdAt: this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      totalAmount: totalAmount ?? this.totalAmount,
      items: items ?? this.items,
    );
  }

  factory OrderModel.fromMap(Map<String, dynamic> map, {List<OrderItem> items = const []}) {
    return OrderModel(
      id: map['id'],
      tableId: map['table_id'],
      waiterId: map['waiter_id'],
      tableName: map['table_name'] ?? '',
      waiterName: map['waiter_name'] ?? '',
      status: OrderStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => OrderStatus.pending,
      ),
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
      totalAmount: map['total_amount'],
      items: items,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'table_id': tableId,
      'waiter_id': waiterId,
      'status': status.toString().split('.').last,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'total_amount': totalAmount,
    };
  }
}
