class AuthenticatedAccount {
  const AuthenticatedAccount({
    required this.id,
    required this.email,
    required this.displayName,
    required this.avatarUrl,
    this.createdAt,
    this.updatedAt,
  });

  factory AuthenticatedAccount.fromJson(Map<String, dynamic> json) {
    return AuthenticatedAccount(
      id: json['id'] as String,
      email: json['email'] as String?,
      displayName: json['name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }

  final String id;
  final String? email;
  final String? displayName;
  final String? avatarUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static DateTime? _parseDate(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      return null;
    }

    return DateTime.tryParse(value);
  }
}
