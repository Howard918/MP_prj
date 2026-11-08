class RagReference {
  final String id;
  final String title;
  final String url;
  final String matchText;

  RagReference({
    required this.id,
    required this.title,
    required this.url,
    required this.matchText,
  });

  factory RagReference.fromJson(Map<String, dynamic> json) {
    return RagReference(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      url: json['url'] ?? '',
      matchText: json['match_text'] ?? '',
    );
  }
}

class RagResult {
  final String answer;
  final List<RagReference> references;

  RagResult({required this.answer, required this.references});

  factory RagResult.fromJson(Map<String, dynamic> json) {
    return RagResult(
      answer: json['answer'] ?? '',
      references: (json['references'] as List<dynamic>?)
              ?.map((e) => RagReference.fromJson(e))
              .toList() ??
          [],
    );
  }
}
