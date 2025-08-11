class UserModel {
  final String uid;
  final String? email;
  final String? fullName;
  final String? occupation;
  final String? area;

  UserModel({
    required this.uid,
    this.email,
    this.fullName,
    this.occupation,
    this.area,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'full_name': fullName,
      'occupation': occupation,
      'area': area,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'],
      fullName: map['full_name'],
      occupation: map['occupation'],
      area: map['area'],
    );
  }
}