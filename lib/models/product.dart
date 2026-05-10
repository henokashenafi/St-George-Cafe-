class Product {
  final int? id;
  final List<int> categoryIds;
  final String name;
  final double price;
  final String? imagePath;

  Product({
    this.id,
    required this.categoryIds,
    required this.name,
    required this.price,
    this.imagePath,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      categoryIds: map['category_ids'] != null
          ? List<int>.from(map['category_ids'] is String
              ? (map['category_ids'] as String).split(',').map(int.parse)
              : map['category_ids'])
          : (map['category_id'] != null ? [map['category_id'] as int] : []),
      name: map['name'],
      price: (map['price'] as num).toDouble(),
      imagePath: map['image_path'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category_ids': categoryIds.join(','),
      'name': name,
      'price': price,
      'image_path': imagePath,
    };
  }
}
