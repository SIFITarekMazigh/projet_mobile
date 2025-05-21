class Profile {
  final String id;
  final String? fullName;
  final String? avatarUrl;
  final DateTime updatedAt;

  Profile({
    required this.id,
    this.fullName,
    this.avatarUrl,
    required this.updatedAt,
  });

  Profile.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        fullName = json['full_name'],
        avatarUrl = json['avatar_url'],
        updatedAt = DateTime.parse(json['updated_at']);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
