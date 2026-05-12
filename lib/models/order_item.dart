class OrderItem {
  final int? id;
  final int? orderId;
  final int productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double subtotal;
  final bool isPrintedToKitchen;
  final String? notes;
  final String? categoryName;
  final int kitchenRound; // 0 = unsent, 1+ = round number sent to kitchen

  OrderItem({
    this.id,
    this.orderId,
    required this.productId,
    required this.productName,
    this.categoryName,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    this.isPrintedToKitchen = false,
    this.notes,
    this.kitchenRound = 0,
  });

  OrderItem copyWith({
    int? id,
    int? orderId,
    int? quantity,
    double? subtotal,
    bool? isPrintedToKitchen,
    String? notes,
    String? categoryName,
    int? kitchenRound,
  }) {
    return OrderItem(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      productId: productId,
      productName: productName,
      categoryName: categoryName ?? this.categoryName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice,
      subtotal: subtotal ?? this.subtotal,
      isPrintedToKitchen: isPrintedToKitchen ?? this.isPrintedToKitchen,
      notes: notes ?? this.notes,
      kitchenRound: kitchenRound ?? this.kitchenRound,
    );
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id'],
      orderId: map['order_id'],
      productId: map['product_id'] ?? 0,
      productName: map['product_name'] ?? '',
      categoryName: map['category_name'],
      quantity: map['quantity'] ?? 1,
      unitPrice: (map['unit_price'] as num? ?? 0).toDouble(),
      subtotal: (map['subtotal'] as num? ?? 0).toDouble(),
      isPrintedToKitchen: map['is_printed_to_kitchen'] == 1,
      notes: map['notes'],
      kitchenRound: (map['kitchen_round'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_id': orderId,
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'subtotal': subtotal,
      'is_printed_to_kitchen': isPrintedToKitchen ? 1 : 0,
      'notes': notes,
      'kitchen_round': kitchenRound,
    };
  }
}
