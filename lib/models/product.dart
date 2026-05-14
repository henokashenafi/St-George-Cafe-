class Product {
  final int? id;
  final int categoryId;
  final String name;
  final String? nameAmharic;
  final double price;
  final String? imagePath;

  Product({
    this.id,
    required this.categoryId,
    required this.name,
    this.nameAmharic,
    required this.price,
    this.imagePath,
  });

  Product copyWith({
    int? id,
    int? categoryId,
    String? name,
    String? nameAmharic,
    double? price,
    String? imagePath,
  }) {
    return Product(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      nameAmharic: nameAmharic ?? this.nameAmharic,
      price: price ?? this.price,
      imagePath: imagePath ?? this.imagePath,
    );
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      categoryId: map['category_id'] ?? 0,
      name: map['name'],
      nameAmharic: map['name_amharic'],
      price: (map['price'] as num).toDouble(),
      imagePath: map['image_path'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category_id': categoryId,
      'name': name,
      'name_amharic': nameAmharic,
      'price': price,
      'image_path': imagePath,
    };
  }
}
