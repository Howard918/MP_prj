import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodels/chat_viewmodel.dart';
import 'result_view.dart';

class ChatView extends ConsumerStatefulWidget {
  const ChatView({super.key});
  @override
  ConsumerState<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends ConsumerState<ChatView> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _showErrorDialog(BuildContext context, WidgetRef ref, String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.wifi_off_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('네트워크 오류'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(chatViewModelProvider.notifier).clearError();
            },
            child: const Text('취소'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(chatViewModelProvider.notifier).retryAIResponse();
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = ref.watch(chatViewModelProvider);

    // 평가 완료 및 음성 재생이 끝났을 때 결과 화면으로 자동 전환
    ref.listen(chatViewModelProvider, (previous, next) {
      if (next.isFinished && next.evaluationResult != null && !next.isSpeaking && !next.hasError) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ResultView()));
      }

      // 네트워크 에러 발생 시 팝업 다이얼로그 표시
      if (previous?.hasError != next.hasError && next.hasError) {
        _showErrorDialog(context, ref, next.errorMessage);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('실전 상황극'),
        actions: [
          IconButton(
            tooltip: '연습 종료',
            icon: const Icon(Icons.exit_to_app),
            onPressed: () {
              ref.read(chatViewModelProvider.notifier).stopSpeaking();
              Navigator.pop(context);
            },
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: viewModel.messages.length,
              itemBuilder: (context, index) {
                final msg = viewModel.messages[index];
                final isUser = msg.role == 'user';
                final isPlaying = viewModel.currentlyPlayingText == msg.content;

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (!isUser) // AI 메시지 옆 스피커 버튼
                        IconButton(
                          icon: Icon(
                            isPlaying ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                            color: isPlaying ? Colors.orange : Colors.green,
                          ),
                          onPressed: () => ref.read(chatViewModelProvider.notifier).toggleSpeak(msg.content),
                        ),
                      Flexible(
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isUser ? Colors.green[100] : Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(msg.content, style: const TextStyle(fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (viewModel.isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text('고객이 응답을 작성하는 중...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),

          // 1. 상황극 종료 후 평가 완료 대기 중이거나 음성 출력 중일 때 표시되는 버튼
          if (viewModel.isFinished)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              child: ElevatedButton.icon(
                onPressed: viewModel.isLoading
                    ? null
                    : () {
                        ref.read(chatViewModelProvider.notifier).stopSpeaking();
                        if (viewModel.evaluationResult != null) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const ResultView()),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  elevation: 2,
                ),
                icon: Icon(viewModel.isLoading ? Icons.hourglass_top : Icons.analytics_outlined, size: 20),
                label: Text(
                  viewModel.isLoading ? '최종 평가 분석 중...' : '결과 확인하기',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            )
          // 2. 상황극 진행 중 고객 음성이 나올 때 표시되는 "즉시 답변하기" 버튼
          else if (viewModel.isSpeaking)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              child: ElevatedButton.icon(
                onPressed: () {
                  ref.read(chatViewModelProvider.notifier).stopSpeaking();
                  _focusNode.requestFocus(); // 키보드 바로 열기
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  elevation: 2,
                ),
                icon: const Icon(Icons.flash_on, size: 20),
                label: const Text('🗣️ 고객 음성 멈추고 즉시 답변하기', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),

          // 하단 입력부 (표준 텍스트 입력창)
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    enabled: !viewModel.isFinished && !viewModel.isLoading && !viewModel.isSpeaking,
                    decoration: InputDecoration(
                      hintText: viewModel.isSpeaking
                          ? '고객 음성이 출력 중입니다...'
                          : '응대 메시지를 입력하세요...',
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (text) {
                      if (text.trim().isNotEmpty) {
                        ref.read(chatViewModelProvider.notifier).sendMessage(text);
                        _textController.clear();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.green),
                  onPressed: viewModel.isFinished || viewModel.isLoading || viewModel.isSpeaking
                      ? null
                      : () {
                          if (_textController.text.trim().isNotEmpty) {
                            ref.read(chatViewModelProvider.notifier).sendMessage(_textController.text);
                            _textController.clear();
                          }
                        },
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
