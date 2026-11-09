import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_model.dart';
import '../models/practice_report.dart';
import '../services/openai_service.dart';
import '../services/audio_service.dart';
import '../services/data_service.dart';

final chatViewModelProvider = ChangeNotifierProvider((ref) => ChatViewModel());

class ChatViewModel extends ChangeNotifier {
  final OpenAIService _openAIService = OpenAIService();
  final AudioService _audioService = AudioService();

  List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => _messages.where((m) => m.role != 'system').toList();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _hasError = false;
  bool get hasError => _hasError;

  String _errorMessage = "";
  String get errorMessage => _errorMessage;

  int _turnCount = 0;
  final int _maxTurns = 4;

  EvaluationResult? _evaluationResult;
  EvaluationResult? get evaluationResult => _evaluationResult;

  bool _isFinished = false;
  bool get isFinished => _isFinished;

  String _evaluationCriteria = "[필수] 정중하고 즉각적인 사과, 고객 요구사항 확인, 매장 매뉴얼에 따른 정중한 안내\n[선택] 매장 상황 세부 설명 및 고객 케어"; // 기본값

  String _currentlyPlayingText = "";
  String get currentlyPlayingText => _currentlyPlayingText;

  bool _isSpeaking = false;
  bool get isSpeaking => _isSpeaking;

  dynamic _currentScenario;
  DataService? _dataService;
  String? _token;
  String? _baseUrl;

  ChatViewModel() {
    _audioService.init(
      onTtsComplete: () {
        _currentlyPlayingText = "";
        _isSpeaking = false;
        notifyListeners();
      },
    );
  }

  void startSession([dynamic scenario, DataService? dataService, String? token, String? baseUrl]) {
    _currentlyPlayingText = "";
    _isSpeaking = false;
    _hasError = false;
    _errorMessage = "";
    _audioService.stopSpeaking();
    _currentScenario = scenario;
    _dataService = dataService;
    _token = token;
    _baseUrl = baseUrl;
    
    String systemPrompt = "너는 카페 진상 고객 또는 다급한 손님 역할을 하는 페르소나 봇이야. 현재 상황은 '주문한 음료가 쏟아져서 화가 난 상태'야. 사용자는 카페 수습 아르바이트생이야. 실제 손님처럼 자연스럽게 대화하고, 아르바이트생의 대응에 따라 감정이 누그러지거나 더 화를 내. 대화는 최대 3-4턴으로 제한해. 먼저 불만이나 문의를 제기하며 대화를 시작해.";
    
    if (scenario != null) {
      systemPrompt = "너는 ${scenario.industry} 손님 역할을 하는 페르소나 봇이야. 현재 상황은 '${scenario.situation}'야. 사용자는 수습 아르바이트생이야. 실제 손님처럼 자연스럽게 대화하고, 아르바이트생의 대응에 따라 반응을 바꿔. 대화는 최대 3-4턴으로 제한해. 먼저 상황에 맞는 불만이나 문의를 제기하며 대화를 시작해.";
      _evaluationCriteria = scenario.expectedActions; // 동적 평가 기준 할당
    }

    systemPrompt += "\n\n중요: 너의 응답은 반드시 다음 JSON 형식으로 작성해. {\"reply\": \"고객으로서 할 말\", \"status\": \"ongoing\" | \"success\" | \"failure\"}\n- ongoing: 대화가 더 필요한 경우\n- success: 상황이 원만히 해결되어 불만이 해소된 경우\n- failure: 알바생의 응대가 매우 부적절하여 화를 내고 대화를 중단하는 경우";

    _messages = [
      ChatMessage(
        role: 'system',
        content: systemPrompt
      )
    ];
    _turnCount = 0;
    _isFinished = false;
    _evaluationResult = null;
    
    // AI의 첫 발화 시작
    _fetchAIResponse();
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || _isFinished) return;

    stopSpeaking(); // 음성 출력 중 사용자가 보내면 음성 중단

    _messages.add(ChatMessage(role: 'user', content: text));
    _turnCount++;
    notifyListeners();

    if (_turnCount >= _maxTurns) {
      await _finishAndEvaluate();
    } else {
      await _fetchAIResponse();
    }
  }

  Future<void> _fetchAIResponse() async {
    _isLoading = true;
    _hasError = false;
    _errorMessage = "";
    notifyListeners();

    try {
      final response = await _openAIService.sendMessage(_messages, _baseUrl ?? 'http://10.0.2.2:8000', _token);
      final replyText = response['reply'] as String? ?? '응답을 불러올 수 없습니다.';
      final status = response['status'] as String? ?? 'ongoing';

      _messages.add(ChatMessage(role: 'assistant', content: replyText));

      // 고객 음성 기본 자동 출력
      _currentlyPlayingText = replyText;
      _isSpeaking = true;
      _audioService.speak(replyText);

      // 조기 종료 (성공 또는 실패)
      if (status == 'success' || status == 'failure') {
        await _finishAndEvaluate();
      } else if (_turnCount >= _maxTurns) {
        await _finishAndEvaluate();
      }
    } catch (e) {
      _hasError = true;
      _errorMessage = "네트워크 연결 또는 백엔드 AI 통신 중 오류가 발생했습니다. 다시 시도하시겠습니까?";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> retryAIResponse() async {
    _hasError = false;
    _errorMessage = "";
    notifyListeners();
    await _fetchAIResponse();
  }

  void clearError() {
    _hasError = false;
    _errorMessage = "";
    notifyListeners();
  }

  Future<void> _finishAndEvaluate() async {
    _isLoading = true;
    _isFinished = true;
    notifyListeners();

    try {
      _evaluationResult = await _openAIService.evaluateSession(_messages, _evaluationCriteria, _baseUrl ?? 'http://10.0.2.2:8000', _token);
      
      // 평가 결과가 성공적으로 도착하면 연습 리포트 저장
      if (_evaluationResult != null && _dataService != null) {
        final report = PracticeReport(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          userId: _dataService?.currentUserId ?? 'user',
          scenarioId: _currentScenario?.id ?? 'custom',
          scenarioTitle: _currentScenario?.title ?? '상황극 연습',
          category: _currentScenario?.category ?? '고객 서비스',
          industry: _currentScenario?.industry ?? '매장 운영',
          dateTime: DateTime.now(),
          score: _evaluationResult!.score,
          feedback: _evaluationResult!.feedback,
          dialogueHistory: List.from(messages),
        );
        _dataService!.addReport(report);
      }
    } catch (e) {
      _evaluationResult = EvaluationResult(score: 0, feedback: "평가 중 오류가 발생했습니다.");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // TTS 음성 재생/중단 제어
  void toggleSpeak(String text) {
    if (_currentlyPlayingText == text) {
      stopSpeaking();
    } else {
      stopSpeaking();
      _currentlyPlayingText = text;
      _isSpeaking = true;
      notifyListeners();
      _audioService.speak(text);
    }
  }

  void stopSpeaking() {
    _audioService.stopSpeaking();
    _currentlyPlayingText = "";
    _isSpeaking = false;
    notifyListeners();
  }
}
