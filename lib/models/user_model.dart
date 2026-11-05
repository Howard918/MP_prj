enum UserRole { general, admin }

class UserModel {
  final int? dbId;
  final String id; // email 또는 아이디
  final String password;
  final String name;
  final UserRole role;
  final int totalSessions;
  final List<String> weaknessCategories;
  final double averageScore;

  UserModel({
    this.dbId,
    required this.id,
    this.password = '',
    required this.name,
    required this.role,
    this.totalSessions = 0,
    this.weaknessCategories = const [],
    this.averageScore = 0.0,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      dbId: json['id'] as int?,
      id: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      role: (json['role'] == 'admin') ? UserRole.admin : UserRole.general,
      totalSessions: json['total_sessions'] as int? ?? 0,
      weaknessCategories: (json['weakness_categories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      averageScore: (json['average_score'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': dbId,
      'email': id,
      'name': name,
      'role': role == UserRole.admin ? 'admin' : 'user',
      'total_sessions': totalSessions,
      'weakness_categories': weaknessCategories,
      'average_score': averageScore,
    };
  }

  bool get isAdmin => role == UserRole.admin;
}
