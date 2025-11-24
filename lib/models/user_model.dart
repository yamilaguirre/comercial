class UserModel {
  final String uid;
  final String email;
  final String accessToken;

  UserModel({
    required this.uid,
    required this.email,
    required this.accessToken,
  });

  factory UserModel.fromApi(Map<String, dynamic> data, String token) {
    return UserModel(
      uid: data['id'].toString(),
      email: data['email'] as String,
      accessToken: token,
    );
  }
}
