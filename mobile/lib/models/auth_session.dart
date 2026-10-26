class AuthUser {
  final String id;
  final String email;
  final String displayName;
  final String createdAt;

  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.createdAt,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      createdAt: json['createdAt'] as String,
    );
  }
}

class AuthSession {
  final String accessToken;
  final String tokenType;
  final int expiresIn;
  final AuthUser user;

  const AuthSession({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
    required this.user,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['accessToken'] as String,
      tokenType: json['tokenType'] as String,
      expiresIn: json['expiresIn'] as int,
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
