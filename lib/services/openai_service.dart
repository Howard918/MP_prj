import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/chat_model.dart';
import '../models/rag_result.dart';

class OpenAIService {
  // 백엔드 AI 프록시 엔드포인트를 통해 통신
  Future<Map<String, dynamic>> sendMessage(
    List<ChatMessage> messages,
    String baseUrl,
    String? token,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ai/chat'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'messages': messages.map((m) => m.toJson()).toList(),
          'temperature': 0.7,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      } else {
        debugPrint('AI Chat Error: ${response.statusCode} - ${response.body}');
        throw Exception('AI 대화 응답 생성 실패');
      }
    } catch (e) {
      debugPrint('AI 대화 통신 오류: $e');
      rethrow;
    }
  }

  // 상황극 종료 후 백엔드 AI 프록시를 통해 평가 수행
  Future<EvaluationResult> evaluateSession(
    List<ChatMessage> messages,
    String criteria,
    String baseUrl,
    String? token,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ai/evaluate'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'messages': messages.map((m) => m.toJson()).toList(),
          'criteria': criteria,
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final resultJson = jsonDecode(utf8.decode(response.bodyBytes));
        return EvaluationResult.fromJson(resultJson);
      } else {
        debugPrint('AI Evaluate Error: ${response.statusCode} - ${response.body}');
        throw Exception('AI 평가 실패');
      }
    } catch (e) {
      debugPrint('AI 평가 통신 오류: $e');
      rethrow;
    }
  }

  // RAG 파이프라인(매뉴얼 검색) 프록시 호출
  Future<RagResult> searchAssistant(
    String query,
    String baseUrl,
    String? token,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ai/search'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'query': query,
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final resultJson = jsonDecode(utf8.decode(response.bodyBytes));
        return RagResult.fromJson(resultJson);
      } else {
        debugPrint('AI Search Error: ${response.statusCode} - ${response.body}');
        throw Exception('AI 어시스턴트 검색 실패');
      }
    } catch (e) {
      debugPrint('AI 검색 통신 오류: $e');
      rethrow;
    }
  }
}
