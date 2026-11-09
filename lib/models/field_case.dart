enum FieldCaseStatus { pending, approved, rejected }

class FieldCase {
  final String id;
  final String authorId;
  final String authorName;
  final String category;
  final String industry;
  final String title;
  final String situation;
  final String responseDetails;
  final DateTime createdAt;
  FieldCaseStatus status;
  String? reviewComment;
  bool isConvertedToScenario;

  FieldCase({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.category = '고객 서비스',
    this.industry = '매장 운영',
    required this.title,
    required this.situation,
    required this.responseDetails,
    required this.createdAt,
    this.status = FieldCaseStatus.pending,
    this.reviewComment,
    this.isConvertedToScenario = false,
  });

  factory FieldCase.fromJson(Map<String, dynamic> json) {
    return FieldCase(
      id: (json['id'] ?? '').toString(),
      authorId: (json['authorId'] ?? 'user').toString(),
      authorName: (json['authorName'] ?? '수습생').toString(),
      category: (json['category'] ?? '고객 서비스').toString(),
      industry: (json['industry'] ?? '매장 운영').toString(),
      title: (json['title'] ?? '').toString(),
      situation: (json['situation'] ?? '').toString(),
      responseDetails: (json['responseDetails'] ?? '').toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
      status: _parseStatus(json['status']),
      reviewComment: json['reviewComment'] as String?,
      isConvertedToScenario: json['isConvertedToScenario'] as bool? ?? false,
    );
  }

  static FieldCaseStatus _parseStatus(dynamic val) {
    if (val == 'approved') return FieldCaseStatus.approved;
    if (val == 'rejected') return FieldCaseStatus.rejected;
    return FieldCaseStatus.pending;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'authorId': authorId,
      'authorName': authorName,
      'category': category,
      'industry': industry,
      'title': title,
      'situation': situation,
      'responseDetails': responseDetails,
      'createdAt': createdAt.toIso8601String(),
      'status': status.name,
      'reviewComment': reviewComment,
      'isConvertedToScenario': isConvertedToScenario,
    };
  }
}
