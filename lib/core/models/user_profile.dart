class UserProfile {
  final String id;
  final String email;
  final String role;
  final String? firstName;
  final String? lastName;

  const UserProfile({
    required this.id,
    required this.email,
    required this.role,
    this.firstName,
    this.lastName,
  });

  String get displayName {
    final name = [firstName, lastName].where((s) => s != null && s.isNotEmpty).join(' ');
    return name.isNotEmpty ? name : email;
  }

  bool get isAdmin => role == 'Admin';
  bool get isManager => role == 'Manager' || role == 'Admin';

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String,
        email: json['email'] as String,
        role: json['role'] as String,
        firstName: json['firstName'] as String?,
        lastName: json['lastName'] as String?,
      );
}
