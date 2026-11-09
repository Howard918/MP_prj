import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/field_case.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../utils/ui_helpers.dart';

class CaseForm extends ConsumerStatefulWidget {
  const CaseForm({super.key});

  @override
  ConsumerState<CaseForm> createState() => _CaseFormState();
}

class _CaseFormState extends ConsumerState<CaseForm> {
  final formKey = GlobalKey<FormState>();

  final titleController = TextEditingController();
  final situationController = TextEditingController();
  final responseController = TextEditingController();
  String selectedIndustry = '카페';

  static const industries = ['카페', '편의점', '식당', '기타'];

  @override
  void dispose() {
    titleController.dispose();
    situationController.dispose();
    responseController.dispose();
    super.dispose();
  }

  void _submitCase() {
    if (!formKey.currentState!.validate()) return;

    final authService = ref.read(authServiceProvider);
    final dataService = ref.read(dataServiceProvider);

    final newCase = FieldCase(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      authorId: authService.currentUser?.id.toString() ?? 'user',
      authorName: authService.currentUser?.name ?? '수습 알바생',
      title: titleController.text.trim(),
      situation: situationController.text.trim(),
      responseDetails: responseController.text.trim(),
      createdAt: DateTime.now(),
    );

    // 💡 토큰과 백엔드 URL을 정확히 전달하여 백엔드 DB 저장 및 관리자 검토 알림 즉시 동기화
    dataService.addFieldCase(
      newCase,
      token: authService.accessToken,
      baseUrl: authService.baseUrl,
    );

    titleController.clear();
    situationController.clear();
    responseController.clear();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('현장 사례 등록 완료'),
        content: const Text('제보해 주신 현장 사례가 성공적으로 제출되었습니다!\n관리자 검토 후 공식 실전 상황극 시나리오로 가공 등록됩니다.'),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // 이전 화면으로 돌아가기
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('현장 사례 등록')),
      body: content([
        Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '실제 매장에서 일어난 구체적인 고객 응대 경험과 대처 결과를 제보해 주세요.',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: titleController,
                validator: (v) => v == null || v.trim().isEmpty ? '상황 제목을 입력하세요.' : null,
                decoration: const InputDecoration(
                  labelText: '상황 제목',
                  hintText: '예: 포장 용기 파손으로 인한 사과 및 음료 재제조',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: situationController,
                validator: (v) => v == null || v.trim().isEmpty ? '발생 상황 및 고객 요청 내용을 입력하세요.' : null,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: '발생 상황 및 고객 발화',
                  hintText: '어떤 상황에서 고객이 무슨 요청이나 컴플레인을 했나요?',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: responseController,
                validator: (v) => v == null || v.trim().isEmpty ? '실제 대처한 내용을 입력하세요.' : null,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: '현장 조치 및 대응 결과',
                  hintText: '실제 현장에서 어떻게 안내하고 문제를 해결하셨나요?',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _submitCase,
                icon: const Icon(Icons.send_rounded),
                label: const Text('검토 요청 및 사례 등록', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        )
      ]),
    );
  }
}
