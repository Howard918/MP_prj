import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/rag_result.dart';
import '../services/openai_service.dart';
import '../services/auth_service.dart';
import 'document_preview_view.dart';

class RagChatMessage {
  final String role; // 'user' or 'ai'
  final String text;
  final List<RagReference> references;
  final bool isError;
  RagChatMessage({required this.role, required this.text, this.references = const [], this.isError = false});
}

class RagChatViewModel extends ChangeNotifier {
  final OpenAIService _openAIService = OpenAIService();
  
  // 현재 화면에 표시되는 메시지 리스트
  List<RagChatMessage> currentMessages = [];
  
  // 직전 검색 결과 히스토리 보관함
  List<RagChatMessage> previousMessages = [];
  
  bool isLoading = false;

  bool get hasPreviousResult => previousMessages.isNotEmpty;

  // 1. 🌟 새로운 검색 시작 (이전 검색 히스토리를 깔끔히 보관하고 새 화면으로 생성)
  Future<void> startNewSearch(String query, String baseUrl, String? token) async {
    if (query.trim().isEmpty) return;

    // 현재 완료된 검색 건이 있다면 직전 검색 히스토리로 보관
    if (currentMessages.isNotEmpty) {
      previousMessages = List.from(currentMessages);
    }

    currentMessages = [RagChatMessage(role: 'user', text: query.trim())];
    isLoading = true;
    notifyListeners();

    try {
      final res = await _openAIService.searchAssistant(query, baseUrl, token);
      currentMessages.add(RagChatMessage(role: 'ai', text: res.answer, references: res.references));
      // 백업 보관함 갱신
      previousMessages = List.from(currentMessages);
    } catch (e) {
      currentMessages.add(RagChatMessage(role: 'ai', text: '검색 중 오류가 발생했습니다.', isError: true));
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // 2. 📋 직전 검색 결과 화면 복원
  void restorePreviousSearch() {
    if (previousMessages.isNotEmpty) {
      currentMessages = List.from(previousMessages);
      notifyListeners();
    }
  }

  // 3. 💬 열린 바텀시트 내부에서 연이어 질문하기 (동일 세션 유지)
  Future<void> sendFollowUpQuery(String query, String baseUrl, String? token) async {
    if (query.trim().isEmpty) return;

    currentMessages.add(RagChatMessage(role: 'user', text: query.trim()));
    isLoading = true;
    notifyListeners();

    try {
      final res = await _openAIService.searchAssistant(query, baseUrl, token);
      currentMessages.add(RagChatMessage(role: 'ai', text: res.answer, references: res.references));
      previousMessages = List.from(currentMessages);
    } catch (e) {
      currentMessages.add(RagChatMessage(role: 'ai', text: '검색 중 오류가 발생했습니다.', isError: true));
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
  
  void clear() {
    currentMessages.clear();
    previousMessages.clear();
    notifyListeners();
  }
}

final ragChatViewModelProvider = ChangeNotifierProvider((ref) => RagChatViewModel());

class RagChatBottomSheet extends ConsumerStatefulWidget {
  const RagChatBottomSheet({super.key});

  @override
  ConsumerState<RagChatBottomSheet> createState() => _RagChatBottomSheetState();
}

class _RagChatBottomSheetState extends ConsumerState<RagChatBottomSheet> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    
    _controller.clear();
    FocusScope.of(context).unfocus();
    
    final authService = ref.read(authServiceProvider);
    ref.read(ragChatViewModelProvider).sendFollowUpQuery(text, authService.baseUrl, authService.accessToken);
    
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = ref.watch(ragChatViewModelProvider);

    // 새 메시지가 추가되면 스크롤 하단으로 이동
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (viewModel.currentMessages.isNotEmpty || viewModel.isLoading) {
        _scrollToBottom();
      }
    });

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  "AI 매장 규정 어시스턴트",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: viewModel.currentMessages.length + (viewModel.isLoading ? 1 : 0),
              itemBuilder: (ctx, index) {
                if (index == viewModel.currentMessages.length && viewModel.isLoading) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.0),
                    child: Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(color: Color(0xff146b59)),
                          SizedBox(height: 12),
                          Text('문서를 검색하고 답변을 생성하는 중...', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                }
                
                final msg = viewModel.currentMessages[index];
                final isUser = msg.role == 'user';
                
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xff146b59) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16).copyWith(
                        bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(16),
                        bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg.text,
                          style: TextStyle(
                            fontSize: 14, 
                            color: isUser ? Colors.white : (msg.isError ? Colors.red : Colors.black87),
                            height: 1.4,
                          ),
                        ),
                        if (msg.references.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text('참고 문서', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: msg.references.map((ref) => ActionChip(
                              padding: EdgeInsets.zero,
                              avatar: const Icon(Icons.menu_book, size: 14, color: Colors.indigo),
                              label: Text(ref.title, style: const TextStyle(fontSize: 11, color: Colors.indigo)),
                              backgroundColor: Colors.indigo.shade50,
                              side: BorderSide(color: Colors.indigo.shade200),
                              onPressed: () {
                                // 💡 백엔드 RAG 인용 URL에서 문서 docId 동적 파싱 (ArgumentError 예외 안전 방어)
                                String rawSegment = ref.url.split('/').last;
                                if (rawSegment.isEmpty) {
                                  rawSegment = ref.id;
                                }

                                String docId = rawSegment;
                                try {
                                  docId = Uri.decodeComponent(rawSegment);
                                } catch (_) {
                                  try {
                                    docId = Uri.decodeFull(rawSegment);
                                  } catch (_) {
                                    docId = rawSegment; // 예외 발생 시 원본 문자열 안전 사용
                                  }
                                }

                                docId = docId.replaceAll('.docx', '').replaceAll('.pdf', '').trim();
                                if (docId.isEmpty) {
                                  docId = 'manual';
                                }

                                Navigator.push(
                                  context,
                                  PageRouteBuilder<void>(
                                    transitionDuration: Duration.zero,
                                    reverseTransitionDuration: Duration.zero,
                                    pageBuilder: (context, animation, secondaryAnimation) => DocumentPreviewScreen(
                                      docId: docId,
                                      title: ref.title,
                                    ),
                                  ),
                                );
                              },
                            )).toList(),
                          ),
                        ]
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // Chat input inside the bottom sheet
          Container(
            constraints: const BoxConstraints(minHeight: 48, maxHeight: 120),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xff146b59).withValues(alpha: 0.35), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    style: const TextStyle(color: Colors.black87, fontSize: 13.5),
                    cursorColor: const Color(0xff146b59),
                    decoration: InputDecoration(
                      hintText: '추가 질문 입력하기...',
                      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                    onChanged: (val) {
                      if (val.endsWith('\n')) {
                        _controller.text = val.substring(0, val.length - 1);
                        _submit();
                      }
                    },
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                const SizedBox(width: 6),
                Material(
                  color: const Color(0xff146b59),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _submit,
                    child: const Padding(
                      padding: EdgeInsets.all(7.0),
                      child: Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
