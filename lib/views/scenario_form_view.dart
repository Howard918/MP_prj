import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/field_case.dart';
import '../models/roleplay_scenario.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';

class ScenarioForm extends ConsumerStatefulWidget {
  final RoleplayScenario? existing;
  final FieldCase? fromCase;

  const ScenarioForm({super.key, this.existing, this.fromCase});

  @override
  ConsumerState<ScenarioForm> createState() => _ScenarioFormState();
}

class _ScenarioFormState extends ConsumerState<ScenarioForm> {
  final formKey = GlobalKey<FormState>();
  late TextEditingController title;
  late TextEditingController situation;
  late TextEditingController mandatoryActions;
  late TextEditingController optionalActions;
  late TextEditingController rules;
  late String category;
  late bool published;
  Set<String> selectedReferences = {};

  final categories = [
    '음료/메뉴',
    '고객 서비스',
    '안전/비상대응',
    '위생/식품안전',
    'POS/금전정산',
    '시설/장비관리',
  ];

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    final c = widget.fromCase;

    title = TextEditingController(text: s?.title ?? c?.title ?? '');
    situation = TextEditingController(text: s?.situation ?? c?.situation ?? '');
    mandatoryActions = TextEditingController(text: s?.mandatoryActions ?? c?.responseDetails ?? '');
    optionalActions = TextEditingController(text: s?.optionalActions ?? '정중하고 신속한 고객 케어 및 안내');
    rules = TextEditingController(text: s?.linkedRules ?? '');
    category = s?.category ?? c?.category ?? categories.first;
    published = s?.isPublished ?? true; // 사례 변환 시 기본 공개
    selectedReferences = {...?s?.referenceCodes};
  }

  @override
  void dispose() {
    title.dispose();
    situation.dispose();
    mandatoryActions.dispose();
    optionalActions.dispose();
    rules.dispose();
    super.dispose();
  }

  String? requiredText(String? value) => value == null || value.trim().isEmpty ? '필수 입력 항목입니다.' : null;

  void save(DataService dataService, {required bool publish}) {
    if (!formKey.currentState!.validate()) return;
    
    final mandatoryText = mandatoryActions.text
        .replaceAll('[필수]', '')
        .replaceAll('[선택]', '')
        .trim();

    final optionalText = optionalActions.text
        .replaceAll('[필수]', '')
        .replaceAll('[선택]', '')
        .trim();

    String combinedActions = '[필수] $mandatoryText';
    if (optionalText.isNotEmpty) {
      combinedActions += '\n[선택] $optionalText';
    }

    if (widget.existing != null) {
      final updatedScenario = RoleplayScenario(
        id: widget.existing!.id,
        category: category,
        title: title.text.trim(),
        situation: situation.text.trim(),
        expectedActions: combinedActions,
        linkedRules: rules.text.trim(),
        referenceCodes: selectedReferences.toList(),
        isPublished: publish,
      );

      dataService.updateScenario(updatedScenario);
    } else {
      final scenario = RoleplayScenario(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        category: category,
        title: title.text.trim(),
        situation: situation.text.trim(),
        expectedActions: combinedActions,
        linkedRules: rules.text.trim(),
        referenceCodes: selectedReferences.toList(),
        isPublished: publish,
      );

      dataService.addScenario(scenario);
    }

    // 현장 사례를 변환한 건인 경우 사례 상태를 '변환 승인'으로 즉시 마킹
    if (widget.fromCase != null) {
      dataService.markCaseAsConverted(widget.fromCase!.id);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(publish ? '시나리오가 저장 및 공개되었습니다.' : '초안으로 저장되었습니다.')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final dataService = ref.watch(dataServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing != null
              ? '시나리오 수정'
              : (widget.fromCase != null ? '현장 사례 ➔ 시나리오 변환' : '신규 시나리오 작성'),
        ),
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.fromCase != null) ...[
              Card(
                color: Colors.teal.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: Color(0xff146b59)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '작성자 [${widget.fromCase!.authorName}] 수습생의 사례를 시나리오로 변환 중입니다.',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xff146b59)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            DropdownButtonFormField<String>(
              value: dataService.categories.contains(category) ? category : (dataService.categories.isNotEmpty ? dataService.categories.first : '고객 서비스'),
              decoration: const InputDecoration(labelText: '업무 카테고리 선택', border: OutlineInputBorder()),
              items: dataService.categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    category = val;
                  });
                }
              },
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: title,
              validator: requiredText,
              decoration: const InputDecoration(
                labelText: '상황극 제목',
                hintText: '예: 주문 재료 품절 및 변경 안내',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: situation,
              validator: requiredText,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '발생 상황 상세 설명',
                hintText: '고객과 아르바이트생이 처한 구체적 상황을 서술합니다.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: mandatoryActions,
              validator: requiredText,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: '필수 대응 조치 (100점 평가 핵심 요건)',
                hintText: '예: 정중한 사과, 품절 상황 및 사유 안내, 대체 메뉴 제안',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: optionalActions,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '선택 대응 조치 (피드백 추천용, 선택사항)',
                hintText: '예: 매장 상황 세부 설명 및 고객 대기 케어',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: rules,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '연결된 매장 운영규칙 (선택)',
                hintText: '예: 01_운영총칙 - 4. 돌발 상황 및 컴플레인 대처',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            ExpansionTile(
              title: Text('근거 자료 연결 (${selectedReferences.length}개 선택)'),
              subtitle: const Text('관련 법령 및 공식 근거 지침 문항'),
              children: [
                for (final ref in dataService.references)
                  CheckboxListTile(
                    dense: true,
                    title: Text('${ref.code} · ${ref.name}'),
                    subtitle: Text(ref.kind),
                    value: selectedReferences.contains(ref.code),
                    onChanged: (checked) => setState(() {
                      if (checked == true) {
                        selectedReferences.add(ref.code);
                      } else {
                        selectedReferences.remove(ref.code);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => save(dataService, publish: false),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                    child: const Text('초안으로 저장'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => save(dataService, publish: true),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xff146b59),
                      minimumSize: const Size(0, 48),
                    ),
                    child: const Text('저장 및 즉시 공개'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
