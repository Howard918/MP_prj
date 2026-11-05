import 'dart:convert';
import 'chat_model.dart';

class PracticeReport {
  final String id;
  final String userId;
  final String scenarioId;
  final String scenarioTitle;
  final String industry;
  final DateTime dateTime;
  final int score;
  final String feedback;
  String? adminComment; // 관리자가 추가 작성한 피드백 코멘트
  final List<ChatMessage> dialogueHistory;

  PracticeReport({
    required this.id,
    this.userId = '',
    required this.scenarioId,
    required this.scenarioTitle,
    required this.industry,
    required this.dateTime,
    required this.score,
    required this.feedback,
    this.adminComment,
    required this.dialogueHistory,
  });

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    final str = value.toString().trim();
    if (str.isEmpty) return DateTime.now();

    try {
      return DateTime.parse(str);
    } catch (_) {
      try {
        final formatted = str.replaceAll(' ', 'T');
        return DateTime.parse(formatted);
      } catch (_) {
        return DateTime.now();
      }
    }
  }

  static List<ChatMessage> _parseDialogueHistory(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw
          .map((e) {
            if (e is Map) {
              return ChatMessage(
                role: (e['role'] ?? 'user').toString(),
                content: (e['content'] ?? '').toString(),
              );
            }
            return null;
          })
          .whereType<ChatMessage>()
          .toList();
    }
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        return _parseDialogueHistory(decoded);
      } catch (_) {}
    }
    return [];
  }

  factory PracticeReport.fromJson(Map<String, dynamic> json) {
    return PracticeReport(
      id: (json['id'] ?? '').toString().trim(),
      userId: (json['user_id'] ?? json['userId'] ?? '').toString().trim(),
      scenarioId: (json['scenario_id'] ?? json['scenarioId'] ?? '').toString().trim(),
      scenarioTitle: (json['scenario_title'] ?? json['scenarioTitle'] ?? '').toString().trim(),
      industry: (json['industry'] ?? '').toString().trim(),
      dateTime: _parseDateTime(json['date_time'] ?? json['dateTime']),
      score: (json['score'] as num?)?.toInt() ?? 0,
      feedback: (json['feedback'] ?? '').toString(),
      adminComment: (json['admin_comment'] ?? json['adminComment']) as String?,
      dialogueHistory: _parseDialogueHistory(json['dialogue_history'] ?? json['dialogueHistory']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'scenarioId': scenarioId,
      'scenarioTitle': scenarioTitle,
      'industry': industry,
      'dateTime': dateTime.toIso8601String(),
      'score': score,
      'feedback': feedback,
      'adminComment': adminComment,
      'dialogueHistory': dialogueHistory.map((m) => m.toJson()).toList(),
    };
  }

  Map<String, dynamic> toBackendJson() {
    return {
      'scenario_id': scenarioId,
      'scenario_title': scenarioTitle,
      'industry': industry,
      'date_time': dateTime.toIso8601String(),
      'score': score,
      'feedback': feedback,
      'admin_comment': adminComment,
      'dialogue_history': dialogueHistory.map((m) => m.toJson()).toList(),
    };
  }
}
