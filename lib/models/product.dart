class Product {
  final int? id;
  final int categoryId;
  final String name;
  final double price;
  final String? imagePath;

  Product({
    this.id,
    required this.categoryId,
    required this.name,
    required this.price,
    this.imagePath,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      categoryId: map['category_id'],
      name: map['name'],
      price: map['price'],
      imagePath: map['image_path'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category_id': categoryId,
      'name': name,
      'price': price,
      'image_path': imagePath,
    };
  }
}
