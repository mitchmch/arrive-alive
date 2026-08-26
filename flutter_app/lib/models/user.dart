class AppUser {
  final int id;
  final String phone;
  final String role;
  final String displayName;
  final String? birthYear;
  final bool isGuest;
  final String? photoPath;

  AppUser({
    required this.id,
    required this.phone,
    required this.role,
    this.displayName = '',
    this.birthYear,
    this.isGuest = false,
    this.photoPath,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] ?? 0,
      phone: json['phone'] ?? '',
      role: json['role'] ?? 'user',
      displayName: json['displayName']?.toString() ?? '',
      birthYear: json['birthYear'],
      isGuest: json['isGuest'] ?? false,
      photoPath: json['photoPath']?.toString(),
    );
  }

  AppUser copyWith({
    int? id,
    String? phone,
    String? role,
    String? displayName,
    String? birthYear,
    bool? isGuest,
    String? photoPath,
    bool clearPhoto = false,
  }) {
    return AppUser(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      displayName: displayName ?? this.displayName,
      birthYear: birthYear ?? this.birthYear,
      isGuest: isGuest ?? this.isGuest,
      photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'role': role,
        'displayName': displayName,
        'birthYear': birthYear,
        'isGuest': isGuest,
        'photoPath': photoPath,
      };
}
