class UserModel {
  final int id;
  final String username;
  final String email;

  UserModel({required this.id, required this.username, required this.email});

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
        id: j['id'] ?? 0,
        username: j['username'] ?? '',
        email: j['email'] ?? '',
      );
}
