class Product {
  final int? id;
  final List<int> categoryIds;
  final String name;
  final String? nameAmharic;
  final double price;
  final String? imagePath;
  final int? stationId;

  int get categoryId => categoryIds.isNotEmpty ? categoryIds.first : 0;

  Product({
    this.id,
    required this.categoryIds,
    required this.name,
    this.nameAmharic,
    required this.price,
    this.imagePath,
    this.stationId,
  });

  Product copyWith({
    int? id,
    List<int>? categoryIds,
    String? name,
    String? nameAmharic,
    double? price,
    String? imagePath,
    int? stationId,
  }) {
    return Product(
      id: id ?? this.id,
      categoryIds: categoryIds ?? this.categoryIds,
      name: name ?? this.name,
      nameAmharic: nameAmharic ?? this.nameAmharic,
      price: price ?? this.price,
      imagePath: imagePath ?? this.imagePath,
      stationId: stationId ?? this.stationId,
    );
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    List<int> parseCategories() {
      if (map['category_ids'] != null && map['category_ids'].toString().isNotEmpty) {
        return map['category_ids'].toString().split(',').map((e) => int.tryParse(e.trim()) ?? 0).where((e) => e > 0).toList();
      }
      if (map['category_id'] != null) {
        return [map['category_id'] as int];
      }
      return [];
    }

    return Product(
      id: map['id'],
      categoryIds: parseCategories(),
      name: map['name'],
      nameAmharic: map['name_amharic'],
      price: (map['price'] as num).toDouble(),
      imagePath: map['image_path'],
      stationId: map['station_id'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category_id': categoryId,
      'category_ids': categoryIds.join(','),
      'name': name,
      'name_amharic': nameAmharic,
      'price': price,
      'image_path': imagePath,
      'station_id': stationId,
    };
  }
}
