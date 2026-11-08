import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/chat_model.dart';
import '../models/rag_result.dart';
import '../utils/server_connection_handler.dart';

class OpenAIService {
  // 백엔드(FastAPI) AI 프록시 엔드포인트를 통해 통신 (클라이언트 단 API 키 100% 제거)
  Future<Map<String, dynamic>> sendMessage(
    List<ChatMessage> messages,
    String baseUrl,
    String? token,
  ) async {
    if (token == null || token.isEmpty) {
      throw Exception('인증 토큰이 없습니다. 다시 로그인해 주세요.');
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ai/chat'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'messages': messages.map((m) => m.toJson()).toList(),
          'temperature': 0.7,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      } else if (response.statusCode == 401) {
        ServerConnectionHandler.handleDisconnection('인증 세션이 만료되었습니다.\n다시 로그인해 주세요.');
        throw Exception('Unauthorized');
      } else {
        debugPrint('AI Chat Proxy Error: ${response.statusCode} - ${response.body}');
        throw Exception('AI 대화 응답 생성 실패');
      }
    } catch (e) {
      debugPrint('AI 대화 프록시 통신 오류: $e');
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
    if (token == null || token.isEmpty) {
      throw Exception('인증 토큰이 없습니다. 다시 로그인해 주세요.');
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ai/evaluate'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'messages': messages.map((m) => m.toJson()).toList(),
          'criteria': criteria,
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final resultJson = jsonDecode(utf8.decode(response.bodyBytes));
        return EvaluationResult.fromJson(resultJson);
      } else if (response.statusCode == 401) {
        ServerConnectionHandler.handleDisconnection('인증 세션이 만료되었습니다.\n다시 로그인해 주세요.');
        throw Exception('Unauthorized');
      } else {
        debugPrint('AI Evaluate Proxy Error: ${response.statusCode} - ${response.body}');
        throw Exception('AI 평가 실패');
      }
    } catch (e) {
      debugPrint('AI 평가 프록시 통신 오류: $e');
      rethrow;
    }
  }

  // RAG 파이프라인(매뉴얼 검색) 프록시 호출
  Future<RagResult> searchAssistant(
    String query,
    String baseUrl,
    String? token,
  ) async {
    if (token == null || token.isEmpty) {
      throw Exception('인증 토큰이 없습니다. 다시 로그인해 주세요.');
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ai/search'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'query': query,
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final resultJson = jsonDecode(utf8.decode(response.bodyBytes));
        return RagResult.fromJson(resultJson);
      } else if (response.statusCode == 401) {
        ServerConnectionHandler.handleDisconnection('인증 세션이 만료되었습니다.\n다시 로그인해 주세요.');
        throw Exception('Unauthorized');
      } else {
        debugPrint('AI Search Proxy Error: ${response.statusCode} - ${response.body}');
        throw Exception('AI 어시스턴트 검색 실패');
      }
    } catch (e) {
      debugPrint('AI 검색 프록시 통신 오류: $e');
      rethrow;
    }
  }
}
