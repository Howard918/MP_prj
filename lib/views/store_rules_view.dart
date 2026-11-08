import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/data_service.dart';
import '../utils/ui_helpers.dart';
import 'document_preview_view.dart';

class StoreRulesView extends ConsumerWidget {
  const StoreRulesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = [
      {
        'title': '카페 매장 매뉴얼',
        'industry': '카페',
        'docId': 'cafe',
        'desc': '카페 매장 운영 지침, 음료 제조 및 고객 응대 수칙',
        'icon': Icons.local_cafe_outlined,
      },
      {
        'title': '편의점 매장 매뉴얼',
        'industry': '편의점',
        'docId': 'convenience_store',
        'desc': '편의점 수습생 가이드, 연령 확인, POS 및 상품 관리 수칙',
        'icon': Icons.storefront_outlined,
      },
      {
        'title': '식당 매장 매뉴얼',
        'industry': '식당',
        'docId': 'restaurant',
        'desc': '식당 홀/주방 위생, 알레르기 안내 및 안전 응대 수칙',
        'icon': Icons.restaurant_outlined,
      },
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('매장 운영규칙')),
      body: content(
        [
          const Text('원하는 매장 카테고리를 터치하면 PDF 매뉴얼 문서로 즉시 이동합니다.'),
          const SizedBox(height: 16),
          for (final cat in categories) ...[
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  backgroundColor: const Color(0xff146b59).withValues(alpha: 0.1),
                  child: Icon(cat['icon'] as IconData, color: const Color(0xff146b59)),
                ),
                title: Text(
                  cat['title'] as String,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Text(
                    cat['desc'] as String,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ),
                trailing: const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent),
                onTap: () {
                  // 💡 PDF 미리보기 진입 및 뒤로가기 시 애니메이션 딜레이로 인한 지연/오류 방지 (Duration.zero)
                  Navigator.push(
                    context,
                    PageRouteBuilder<void>(
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
                      pageBuilder: (context, animation, secondaryAnimation) => DocumentPreviewScreen(
                        docId: cat['docId'] as String,
                        title: cat['title'] as String,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
        onRefresh: () async {
          await ref.read(dataServiceProvider).refreshData();
        },
      ),
    );
  }
}
