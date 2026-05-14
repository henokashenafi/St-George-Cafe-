class Category {
  final int? id;
  final String name;
  final String? nameAmharic;
  final String? icon;

  Category({this.id, required this.name, this.nameAmharic, this.icon});

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'],
      nameAmharic: map['name_amharic'],
      icon: map['icon'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'name_amharic': nameAmharic,
      'icon': icon,
    };
  }
}
