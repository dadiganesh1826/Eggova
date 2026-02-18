class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String? address;
  final String district;
  final String? state;
  final String? pincode;
  final String role;
  final String? fcmToken;
  final DateTime? createdAt;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.address,
    required this.district,
    this.state,
    this.pincode,
    required this.role,
    this.fcmToken,
    this.createdAt,
  });

  bool get isAdmin => role == 'admin';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      address: json['address'],
      district: json['district'] ?? '',
      state: json['state'],
      pincode: json['pincode'],
      role: json['role'] ?? 'user',
      fcmToken: json['fcmToken'] ?? json['fcm_token'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : (json['created_at'] != null ? DateTime.parse(json['created_at']) : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'district': district,
      'state': state,
      'pincode': pincode,
      'role': role,
    };
  }
}
