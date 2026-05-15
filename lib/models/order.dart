import 'package:st_george_pos/models/order_item.dart';

enum OrderStatus { pending, completed, cancelled }

class OrderModel {
  final int? id;
  final int tableId;
  final int waiterId;
  final int? cashierId;
  final String tableName;
  final String? tableNameAmharic;
  final String waiterName;
  final String? waiterNameAmharic;
  final String cashierName;
  final OrderStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double totalAmount;   // subtotal (items only, no charges)
  final double serviceCharge; // computed at bill time
  final double discountAmount;
  final String paymentMethod;
  final int? shiftId;
  final String? customerTin;
  final List<OrderItem> items;

  OrderModel({
    this.id,
    required this.tableId,
    required this.waiterId,
    this.cashierId,
    required this.tableName,
    this.tableNameAmharic,
    required this.waiterName,
    this.waiterNameAmharic,
    this.cashierName = '',
    this.status = OrderStatus.pending,
    required this.createdAt,
    required this.updatedAt,
    this.totalAmount = 0.0,
    this.serviceCharge = 0.0,
    this.discountAmount = 0.0,
    this.paymentMethod = 'cash',
    this.shiftId,
    this.customerTin,
    this.items = const [],
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
    String? paymentMethod,
    int? shiftId,
    String? customerTin,
    List<OrderItem>? items,
  }) {
    return OrderModel(
      id: id ?? this.id,
      tableId: tableId,
      waiterId: waiterId,
      cashierId: cashierId ?? this.cashierId,
      tableName: tableName,
      tableNameAmharic: tableNameAmharic,
      waiterName: waiterName,
      waiterNameAmharic: waiterNameAmharic,
      cashierName: cashierName ?? this.cashierName,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      totalAmount: totalAmount ?? this.totalAmount,
      serviceCharge: serviceCharge ?? this.serviceCharge,
      discountAmount: discountAmount ?? this.discountAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      shiftId: shiftId ?? this.shiftId,
      customerTin: customerTin ?? this.customerTin,
      items: items ?? this.items,
    );
  }

  factory OrderModel.fromMap(Map<String, dynamic> map,
      {List<OrderItem> items = const []}) {
    return OrderModel(
      id: map['id'],
      tableId: map['table_id'] ?? 0,
      waiterId: map['waiter_id'] ?? 0,
      cashierId: map['cashier_id'],
      tableName: map['table_name'] ?? '',
      tableNameAmharic: map['table_name_amharic'],
      waiterName: map['waiter_name'] ?? '',
      waiterNameAmharic: map['waiter_name_amharic'],
      cashierName: map['cashier_name'] ?? '',
      status: OrderStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => OrderStatus.pending,
      ),
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at']) 
          : DateTime.now(),
      updatedAt: map['updated_at'] != null 
          ? DateTime.parse(map['updated_at']) 
          : DateTime.now(),
      totalAmount: (map['total_amount'] as num? ?? 0).toDouble(),
      serviceCharge: (map['service_charge'] as num? ?? 0).toDouble(),
      discountAmount: (map['discount_amount'] as num? ?? 0).toDouble(),
      paymentMethod: map['payment_method'] ?? 'cash',
      shiftId: map['shift_id'],
      customerTin: map['customer_tin'],
      items: items,
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
      'payment_method': paymentMethod,
      'shift_id': shiftId,
      'customer_tin': customerTin,
      'table_name': tableName,
      'table_name_amharic': tableNameAmharic,
      'waiter_name': waiterName,
      'waiter_name_amharic': waiterNameAmharic,
      'cashier_name': cashierName,
    };
  }
}
