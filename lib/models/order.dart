import 'package:st_george_pos/models/order_item.dart';

enum OrderStatus { pending, completed, cancelled, held }

class OrderModel {
  final int? id;
  final int tableId;
  final int waiterId;
  final int? cashierId;
  final String tableName;
  final String waiterName;
  final String cashierName;
  final OrderStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double totalAmount;   // subtotal (items only, no charges)
  final double serviceCharge; // computed at bill time
  final double discountAmount;
  final List<OrderItem> items;
  final String sessionId;     // Track multiple sessions per table
  final bool isHeld;          // Order holding status
  final int? parentOrderId;   // Link to main order for held orders
  final int? zoneId;          // Zone assignment for automatic waiter mapping

  OrderModel({
    this.id,
    required this.tableId,
    required this.waiterId,
    this.cashierId,
    required this.tableName,
    required this.waiterName,
    this.cashierName = '',
    this.status = OrderStatus.pending,
    required this.createdAt,
    required this.updatedAt,
    this.totalAmount = 0.0,
    this.serviceCharge = 0.0,
    this.discountAmount = 0.0,
    this.items = const [],
    this.sessionId = '',
    this.isHeld = false,
    this.parentOrderId,
    this.zoneId,
  });

  double get grandTotal => totalAmount + serviceCharge - discountAmount;

  OrderModel copyWith({
    int? id,
    int? cashierId,
    String? cashierName,
    OrderStatus? status,
    DateTime? updatedAt,
    double? totalAmount,
    double? serviceCharge,
    double? discountAmount,
    List<OrderItem>? items,
    String? sessionId,
    bool? isHeld,
    int? parentOrderId,
    int? zoneId,
  }) {
    return OrderModel(
      id: id ?? this.id,
      tableId: tableId,
      waiterId: waiterId,
      cashierId: cashierId ?? this.cashierId,
      tableName: tableName,
      waiterName: waiterName,
      cashierName: cashierName ?? this.cashierName,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      totalAmount: totalAmount ?? this.totalAmount,
      serviceCharge: serviceCharge ?? this.serviceCharge,
      discountAmount: discountAmount ?? this.discountAmount,
      items: items ?? this.items,
      sessionId: sessionId ?? this.sessionId,
      isHeld: isHeld ?? this.isHeld,
      parentOrderId: parentOrderId ?? this.parentOrderId,
      zoneId: zoneId ?? this.zoneId,
    );
  }

  factory OrderModel.fromMap(Map<String, dynamic> map,
      {List<OrderItem> items = const []}) {
    return OrderModel(
      id: map['id'],
      tableId: map['table_id'],
      waiterId: map['waiter_id'],
      cashierId: map['cashier_id'],
      tableName: map['table_name'] ?? '',
      waiterName: map['waiter_name'] ?? '',
      cashierName: map['cashier_name'] ?? '',
      status: OrderStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => OrderStatus.pending,
      ),
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
      totalAmount: (map['total_amount'] as num).toDouble(),
      serviceCharge: (map['service_charge'] as num? ?? 0).toDouble(),
      discountAmount: (map['discount_amount'] as num? ?? 0).toDouble(),
      items: items,
      sessionId: map['session_id'] ?? '',
      isHeld: map['is_held'] ?? false,
      parentOrderId: map['parent_order_id'],
      zoneId: map['zone_id'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'table_id': tableId,
      'waiter_id': waiterId,
      'cashier_id': cashierId,
      'status': status.toString().split('.').last,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'total_amount': totalAmount,
      'service_charge': serviceCharge,
      'discount_amount': discountAmount,
      'session_id': sessionId,
      'is_held': isHeld,
      'parent_order_id': parentOrderId,
      'zone_id': zoneId,
    };
  }
}
