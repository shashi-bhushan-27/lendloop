enum UserRole { student, admin }
enum UserStatus { active, suspended, pending }

class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final String? avatarUrl;
  final String? bio;
  final String? department;
  final String? regNumber;
  final String? hostelBlock;
  final String? preferredPickupLocation;
  final double trustScore;
  final int totalLends;
  final int totalBorrows;
  final UserRole role;
  final UserStatus status;
  final bool isEmailVerified;
  final bool phoneVerified;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    this.avatarUrl,
    this.bio,
    this.department,
    this.regNumber,
    this.hostelBlock,
    this.preferredPickupLocation,
    required this.trustScore,
    required this.totalLends,
    required this.totalBorrows,
    required this.role,
    required this.status,
    required this.isEmailVerified,
    required this.phoneVerified,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      phone: json['phone_number'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      department: json['department'] as String?,
      regNumber: json['reg_number'] as String?,
      hostelBlock: json['hostel_block'] as String?,
      preferredPickupLocation: json['preferred_pickup_location'] as String?,
      trustScore: (json['trust_score'] as num?)?.toDouble() ?? 80.0,
      totalLends: (json['total_lends'] as num?)?.toInt() ?? 0,
      totalBorrows: (json['total_borrows'] as num?)?.toInt() ?? 0,
      role: UserRole.values.firstWhere(
        (e) => e.name == (json['role'] as String? ?? 'student'),
        orElse: () => UserRole.student,
      ),
      status: UserStatus.values.firstWhere(
        (e) => e.name == (json['status'] as String? ?? 'active'),
        orElse: () => UserStatus.active,
      ),
      isEmailVerified: json['is_email_verified'] as bool? ?? false,
      phoneVerified: json['phone_verified'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'full_name': fullName,
    'phone_number': phone,
    'avatar_url': avatarUrl,
    'bio': bio,
    'department': department,
    'reg_number': regNumber,
    'hostel_block': hostelBlock,
    'preferred_pickup_location': preferredPickupLocation,
    'trust_score': trustScore,
    'total_lends': totalLends,
    'total_borrows': totalBorrows,
    'role': role.name,
    'status': status.name,
    'is_email_verified': isEmailVerified,
    'phone_verified': phoneVerified,
    'created_at': createdAt.toIso8601String(),
  };

  UserModel copyWith({
    String? fullName,
    String? phone,
    String? avatarUrl,
    String? bio,
    String? department,
    String? hostelBlock,
    String? preferredPickupLocation,
    double? trustScore,
  }) {
    return UserModel(
      id: id,
      email: email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      department: department ?? this.department,
      regNumber: regNumber,
      hostelBlock: hostelBlock ?? this.hostelBlock,
      preferredPickupLocation: preferredPickupLocation ?? this.preferredPickupLocation,
      trustScore: trustScore ?? this.trustScore,
      totalLends: totalLends,
      totalBorrows: totalBorrows,
      role: role,
      status: status,
      isEmailVerified: isEmailVerified,
      phoneVerified: phoneVerified,
      createdAt: createdAt,
    );
  }

  String get trustLabel {
    if (trustScore >= 75) return 'Trusted';
    if (trustScore >= 40) return 'Moderate';
    return 'New';
  }
}
