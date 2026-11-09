import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../utils/ui_helpers.dart';
import 'document_preview_view.dart';

class StoreRulesView extends ConsumerWidget {
  const StoreRulesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataService = ref.watch(dataServiceProvider);
    final docs = dataService.manualDocs;

    return Scaffold(
      appBar: AppBar(title: const Text('매장 운영규칙 & 매뉴얼')),
      body: content(
        [
          Text(
            docs.isNotEmpty
                ? '현재 매장(backend/doc/)에 등록된 총 ${docs.length}개의 매뉴얼 문서를 확인하세요.'
                : '현재 매장에 등록된 운영 매뉴얼 문서를 불러오는 중입니다.',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          if (docs.isEmpty)
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(18),
                leading: const Icon(Icons.description_outlined, color: Colors.grey, size: 28),
                title: const Text('등록된 매장 매뉴얼 문서가 없습니다.', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('backend/doc/ 경로에 .docx 매뉴얼 파일을 배치해 주세요.'),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    final authService = ref.read(authServiceProvider);
                    ref.read(dataServiceProvider).refreshData(
                          token: authService.accessToken,
                          baseUrl: authService.baseUrl,
                        );
                  },
                ),
              ),
            )
          else
            for (int i = 0; i < docs.length; i++) ...[
              Card(
                elevation: 2.5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: const Color(0xff146b59).withValues(alpha: 0.1),
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xff146b59)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              docs[i]['title'] ?? '매장 운영 매뉴얼',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5),
                            ),
                          ),
                          const Chip(
                            label: Text('PDF 미리보기', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                            backgroundColor: Color(0xff146b59),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.insert_drive_file_outlined, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '원본 파일: ${docs[i]['filename']}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xff146b59),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                          label: Text(
                            '${docs[i]['title']} PDF 열람',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              PageRouteBuilder<void>(
                                transitionDuration: Duration.zero,
                                reverseTransitionDuration: Duration.zero,
                                pageBuilder: (context, animation, secondaryAnimation) => DocumentPreviewScreen(
                                  docId: docs[i]['doc_id']!,
                                  title: docs[i]['title']!,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
        ],
        onRefresh: () async {
          final authService = ref.read(authServiceProvider);
          await ref.read(dataServiceProvider).refreshData(
                token: authService.accessToken,
                baseUrl: authService.baseUrl,
              );
        },
      ),
    );
  }
}
