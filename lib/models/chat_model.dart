class ChatMessage {
  final String role; // 'system', 'user', 'assistant'
  final String content;

  ChatMessage({required this.role, required this.content});

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

class EvaluationResult {
  final int score;
  final String feedback;

  EvaluationResult({required this.score, required this.feedback});

  factory EvaluationResult.fromJson(Map<String, dynamic> json) {
    return EvaluationResult(
      score: json['score'] ?? 0,
      feedback: json['feedback'] ?? '피드백을 불러올 수 없습니다.',
    );
  }
}
