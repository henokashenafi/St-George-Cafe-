enum UserRole { director, cashier }

class AppUser {
  final int? id;
  final String username;
  final String passwordHash;
  final UserRole role;
  final bool isActive;

  AppUser({
    this.id,
    required this.username,
    required this.passwordHash,
    required this.role,
    this.isActive = true,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'],
      username: map['username'],
      passwordHash: map['password_hash'],
      role: UserRole.values.firstWhere(
        (e) => e.toString().split('.').last == map['role'],
        orElse: () => UserRole.cashier,
      ),
      isActive: map['is_active'] == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'password_hash': passwordHash,
      'role': role.toString().split('.').last,
      'is_active': isActive ? 1 : 0,
    };
  }
}
