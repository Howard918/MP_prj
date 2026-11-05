import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/official_reference.dart';
import '../services/data_service.dart';
import '../utils/ui_helpers.dart';

class RulesPage extends ConsumerWidget {
  const RulesPage({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataService = ref.watch(dataServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('운영규칙 및 공식 근거')),
      body: content(
        [
          const Text('레퍼런스 문서의 출처를 법령, 공식 지침, 매장 자체 규칙으로 나누어 표시합니다.'),
          const SizedBox(height: 8),
          const Card(child: ListTile(leading: Icon(Icons.info_outline), title: Text('적용 범위 확인'), subtitle: Text('가상 매장 시연 자료입니다. 실제 의무는 영업신고 유형, 취급 품목, 사업장 규모 등 적용 조건을 확인해야 합니다. 운영 절차 자체를 법적 의무라고 표현하지 않습니다.'))),
          for (final ref in dataService.references) _ReferenceCard(reference: ref),
        ],
        onRefresh: () async {
          await ref.read(dataServiceProvider).refreshData();
        },
      ),
    );
  }
}

class _ReferenceCard extends StatelessWidget {
  const _ReferenceCard({required this.reference});
  final OfficialReference reference;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.menu_book_outlined),
      title: Text('${reference.code} · ${reference.name}'),
      subtitle: Text('${reference.kind}\n${reference.scope}${reference.url.isEmpty ? '' : '\n${reference.url}'}'),
      isThreeLine: true,
    ),
  );
}
