class OrderItem {
  final int? id;
  final int? orderId;
  final int productId;
  final String productName;
  final String? productNameAmharic;
  final int quantity;
  final double unitPrice;
  final double subtotal;
  final bool isPrintedToKitchen;
  final String? notes;
  final String? categoryName;
  final int kitchenRound; // 0 = unsent, 1+ = round number sent to kitchen
  final int? stationId;
  final String? stationName;

  OrderItem({
    this.id,
    this.orderId,
    required this.productId,
    required this.productName,
    this.productNameAmharic,
    this.categoryName,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    this.isPrintedToKitchen = false,
    this.notes,
    this.kitchenRound = 0,
    this.stationId,
    this.stationName,
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
    int? stationId,
    String? stationName,
  }) {
    return OrderItem(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      productId: productId,
      productName: productName,
      productNameAmharic: productNameAmharic,
      categoryName: categoryName ?? this.categoryName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice,
      subtotal: subtotal ?? this.subtotal,
      isPrintedToKitchen: isPrintedToKitchen ?? this.isPrintedToKitchen,
      notes: notes ?? this.notes,
      kitchenRound: kitchenRound ?? this.kitchenRound,
      stationId: stationId ?? this.stationId,
      stationName: stationName ?? this.stationName,
    );
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id'],
      orderId: map['order_id'],
      productId: map['product_id'] ?? 0,
      productName: map['product_name'] ?? '',
      productNameAmharic: map['product_name_amharic'],
      categoryName: map['category_name'],
      quantity: map['quantity'] ?? 1,
      unitPrice: (map['unit_price'] as num? ?? 0).toDouble(),
      subtotal: (map['subtotal'] as num? ?? 0).toDouble(),
      isPrintedToKitchen: map['is_printed_to_kitchen'] == 1,
      notes: map['notes'],
      kitchenRound: (map['kitchen_round'] as int?) ?? 0,
      stationId: map['station_id'],
      stationName: map['station_name'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_id': orderId,
      'product_id': productId,
      'product_name': productName,
      'product_name_amharic': productNameAmharic,
      'quantity': quantity,
      'unit_price': unitPrice,
      'subtotal': subtotal,
      'is_printed_to_kitchen': isPrintedToKitchen ? 1 : 0,
      'notes': notes,
      'kitchen_round': kitchenRound,
      'category_name': categoryName,
      'station_id': stationId,
      'station_name': stationName,
    };
  }
}
