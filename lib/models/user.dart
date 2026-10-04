enum UserRole { viewer, creator, admin }

class User {
  final String id;
  final String name;
  final String username;
  final String avatarUrl;
  final UserRole role;
  final bool isVerifiedCreator;
  final String? bio;
  final int followerCount;

  User({
    required this.id,
    required this.name,
    required this.username,
    required this.avatarUrl,
    required this.role,
    this.isVerifiedCreator = false,
    this.bio,
    this.followerCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'username': username,
        'avatarUrl': avatarUrl,
        'role': role.index,
        'isVerifiedCreator': isVerifiedCreator,
        'bio': bio,
        'followerCount': followerCount,
      };

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'],
        name: json['name'],
        username: json['username'],
        avatarUrl: json['avatarUrl'],
        role: UserRole.values[json['role']],
        isVerifiedCreator: json['isVerifiedCreator'] ?? false,
        bio: json['bio'],
        followerCount: json['followerCount'] ?? 0,
      );

  User copyWith({
    String? name,
    String? avatarUrl,
    UserRole? role,
    bool? isVerifiedCreator,
    String? bio,
    int? followerCount,
  }) {
    return User(
      id: id,
      name: name ?? this.name,
      username: username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      isVerifiedCreator: isVerifiedCreator ?? this.isVerifiedCreator,
      bio: bio ?? this.bio,
      followerCount: followerCount ?? this.followerCount,
    );
  }
}
