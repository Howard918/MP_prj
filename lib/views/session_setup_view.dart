import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/roleplay_scenario.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../viewmodels/chat_viewmodel.dart';
import 'chat_view.dart';

class SessionSetupView extends ConsumerWidget {
  final dynamic scenario;
  const SessionSetupView({super.key, this.scenario});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = scenario?.title ?? '실전 대처 연습';
    final industry = scenario?.industry ?? '일반';
    final situation = scenario?.situation ?? '주문한 음료가 쏟아진 상황';

    final String mandatory = (scenario is RoleplayScenario)
        ? (scenario as RoleplayScenario).mandatoryActions
        : (scenario?.expectedActions ?? '정중한 사과 및 안내');

    final String optional = (scenario is RoleplayScenario)
        ? (scenario as RoleplayScenario).optionalActions
        : '';

    return Scaffold(
      appBar: AppBar(title: const Text('훈련 세션 준비')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(label: Text('$industry · AI 상황극')),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            // 상황 개요 카드
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('상황 개요', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(situation, style: const TextStyle(fontSize: 15, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 필수 vs 선택 조치 평가 기준 안내 카드
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.verified, color: Colors.green, size: 20),
                      SizedBox(width: 6),
                      Text('평가 및 대응 조치 기준', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const Divider(height: 20),
                  const Text('필수 대응 항목', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green)),
                  const SizedBox(height: 4),
                  Text(mandatory, style: const TextStyle(fontSize: 14, height: 1.4)),
                  if (optional.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('선택 대응 항목', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.orange)),
                    const SizedBox(height: 4),
                    Text(optional, style: const TextStyle(fontSize: 14, height: 1.4, color: Colors.black87)),
                  ]
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Text(
              '고객 음성이 재생되는 중 즉시 답변 버튼을 눌러 바로 응대하실 수 있습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                final dataService = ref.read(dataServiceProvider);
                final authService = ref.read(authServiceProvider);
                ref.read(chatViewModelProvider.notifier).startSession(
                  scenario,
                  dataService,
                  authService.accessToken,
                  authService.baseUrl,
                );
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ChatView()));
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('상황극 시작', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}
