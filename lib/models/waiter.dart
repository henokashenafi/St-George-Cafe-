class Waiter {
  final int? id;
  final String name;
  final String code;

  Waiter({this.id, required this.name, required this.code});

  factory Waiter.fromMap(Map<String, dynamic> map) {
    return Waiter(
      id: map['id'],
      name: map['name'],
      code: map['code'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
    };
  }
}
