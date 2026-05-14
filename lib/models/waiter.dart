class Waiter {
  final int? id;
  final String name;
  final String? nameAmharic;
  final String code;

  Waiter({this.id, required this.name, this.nameAmharic, required this.code});

  factory Waiter.fromMap(Map<String, dynamic> map) {
    return Waiter(
      id: map['id'],
      name: map['name'],
      nameAmharic: map['name_amharic'],
      code: map['code'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'name_amharic': nameAmharic,
      'code': code,
    };
  }
}
