import 'dart:convert';

/// A signed-in account: the server's session token plus profile details.
class Session {
  const Session({
    required this.token,
    required this.userId,
    this.name,
    this.email,
    this.picture,
  });

  factory Session.fromJson(Map<String, Object?> json) {
    final user = (json['user'] as Map?)?.cast<String, Object?>() ?? const {};
    return Session(
      token: json['token']! as String,
      userId: (user['id'] ?? json['userId'])! as String,
      name: user['name'] as String? ?? json['name'] as String?,
      email: user['email'] as String? ?? json['email'] as String?,
      picture: user['picture'] as String? ?? json['picture'] as String?,
    );
  }

  final String token;
  final String userId;
  final String? name;
  final String? email;
  final String? picture;

  Map<String, Object?> toJson() => {
    'token': token,
    'userId': userId,
    'name': name,
    'email': email,
    'picture': picture,
  };

  Session withToken(String token) => Session(
    token: token,
    userId: userId,
    name: name,
    email: email,
    picture: picture,
  );

  /// When the token was issued (from its JWT payload), if readable.
  DateTime? get issuedAt {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final iat = payload is Map ? payload['iat'] : null;
      return iat is int
          ? DateTime.fromMillisecondsSinceEpoch(iat * 1000, isUtc: true)
          : null;
    } on FormatException {
      return null;
    }
  }
}
