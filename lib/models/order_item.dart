class OrderItem {
  final int? id;
  final int? orderId;
  final int productId;
  final String productName; // Added for convenience in UI
  final int quantity;
  final double unitPrice;
  final double subtotal;
  final bool isPrintedToKitchen;
  final String? notes;

  OrderItem({
    this.id,
    this.orderId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    this.isPrintedToKitchen = false,
    this.notes,
  });

  OrderItem copyWith({
    int? id,
    int? orderId,
    int? quantity,
    double? subtotal,
    bool? isPrintedToKitchen,
    String? notes,
  }) {
    return OrderItem(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      productId: this.productId,
      productName: this.productName,
      quantity: quantity ?? this.quantity,
      unitPrice: this.unitPrice,
      subtotal: subtotal ?? this.subtotal,
      isPrintedToKitchen: isPrintedToKitchen ?? this.isPrintedToKitchen,
      notes: notes ?? this.notes,
    );
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id'],
      orderId: map['order_id'],
      productId: map['product_id'],
      productName: map['product_name'] ?? '',
      quantity: map['quantity'],
      unitPrice: map['unit_price'],
      subtotal: map['subtotal'],
      isPrintedToKitchen: map['is_printed_to_kitchen'] == 1,
      notes: map['notes'],
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
    };
  }
}
