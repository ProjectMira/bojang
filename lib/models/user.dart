class User {
  final String id;
  final String email;
  final String username;
  final String displayName;
  final String? profileImageUrl;
  final DateTime createdAt;
  final DateTime? lastLogin;
  final bool isActive;
  final String timezone;
  final String preferredLanguage;
  final String? deviceId;
  final DateTime? lastSync;
  final String? googleId;
  final AuthProvider authProvider;

  User({
    required this.id,
    required this.email,
    required this.username,
    required this.displayName,
    this.profileImageUrl,
    required this.createdAt,
    this.lastLogin,
    this.isActive = true,
    this.timezone = 'UTC',
    this.preferredLanguage = 'en',
    this.deviceId,
    this.lastSync,
    this.googleId,
    this.authProvider = AuthProvider.email,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      username: json['username'] as String,
      displayName: json['display_name'] as String,
      profileImageUrl: json['profile_image_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastLogin: json['last_login'] != null 
          ? DateTime.parse(json['last_login'] as String) 
          : null,
      isActive: json['is_active'] as bool? ?? true,
      timezone: json['timezone'] as String? ?? 'UTC',
      preferredLanguage: json['preferred_language'] as String? ?? 'en',
      deviceId: json['device_id'] as String?,
      lastSync: json['last_sync'] != null 
          ? DateTime.parse(json['last_sync'] as String) 
          : null,
      googleId: json['google_id'] as String?,
      authProvider: AuthProvider.values.firstWhere(
        (e) => e.toString() == 'AuthProvider.${json['auth_provider'] ?? 'email'}',
        orElse: () => AuthProvider.email,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'display_name': displayName,
      'profile_image_url': profileImageUrl,
      'created_at': createdAt.toIso8601String(),
      'last_login': lastLogin?.toIso8601String(),
      'is_active': isActive,
      'timezone': timezone,
      'preferred_language': preferredLanguage,
      'device_id': deviceId,
      'last_sync': lastSync?.toIso8601String(),
      'google_id': googleId,
      'auth_provider': authProvider.toString().split('.').last,
    };
  }

  User copyWith({
    String? id,
    String? email,
    String? username,
    String? displayName,
    String? profileImageUrl,
    DateTime? createdAt,
    DateTime? lastLogin,
    bool? isActive,
    String? timezone,
    String? preferredLanguage,
    String? deviceId,
    DateTime? lastSync,
    String? googleId,
    AuthProvider? authProvider,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      isActive: isActive ?? this.isActive,
      timezone: timezone ?? this.timezone,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      deviceId: deviceId ?? this.deviceId,
      lastSync: lastSync ?? this.lastSync,
      googleId: googleId ?? this.googleId,
      authProvider: authProvider ?? this.authProvider,
    );
  }
}

enum AuthProvider {
  email,
  google,
}
