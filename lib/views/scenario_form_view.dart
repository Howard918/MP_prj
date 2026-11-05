import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/roleplay_scenario.dart';
import '../models/field_case.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../utils/ui_helpers.dart';

class ScenarioForm extends ConsumerStatefulWidget {
  const ScenarioForm({this.existing, this.fromCase, super.key});
  final RoleplayScenario? existing;
  final FieldCase? fromCase;

  @override
  ConsumerState<ScenarioForm> createState() => _ScenarioFormState();
}

class _ScenarioFormState extends ConsumerState<ScenarioForm> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController title;
  late final TextEditingController situation;
  late final TextEditingController mandatoryActions;
  late final TextEditingController optionalActions;
  late final TextEditingController rules;
  late String industry;
  late bool published;
  late Set<String> selectedReferences;
  late Set<String> selectedRules;
  static const industries = ['카페', '편의점', '식당', '기타'];

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
    industry = s?.industry ?? c?.industry ?? industries.first;
    published = s?.isPublished ?? true; // 사례 변환 시 기본 공개
    selectedReferences = {...?s?.referenceCodes};
    
    final dataService = ref.read(dataServiceProvider);
    selectedRules = s == null ? <String>{} : (dataService.rulesByIndustry[s.industry] ?? const <String>[])
        .where((rule) => s.linkedRules.split('; ').contains(rule)).toSet();
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

    final authService = ref.read(authServiceProvider);
    final token = authService.accessToken;
    final baseUrl = authService.baseUrl;
    final creatorId = authService.currentUser?.id;

    if (widget.existing != null) {
      // 기존 인스턴스 직접 오염 방지 및 변경 사항 대조용 신규 인스턴스 생성
      final updatedScenario = RoleplayScenario(
        id: widget.existing!.id,
        industry: industry,
        title: title.text.trim(),
        situation: situation.text.trim(),
        expectedActions: combinedActions,
        linkedRules: [
          ...selectedRules,
          if (rules.text.trim().isNotEmpty) rules.text.trim(),
        ].join('; '),
        referenceCodes: selectedReferences.toList(),
        isPublished: publish,
      );

      dataService.updateScenario(updatedScenario, token: token, baseUrl: baseUrl, creatorId: creatorId);
    } else {
      final scenario = RoleplayScenario(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        industry: industry,
        title: title.text.trim(),
        situation: situation.text.trim(),
        expectedActions: combinedActions,
        linkedRules: [
          ...selectedRules,
          if (rules.text.trim().isNotEmpty) rules.text.trim(),
        ].join('; '),
        referenceCodes: selectedReferences.toList(),
        isPublished: publish,
      );

      dataService.addScenario(scenario, token: token, baseUrl: baseUrl, creatorId: creatorId);
    }

    // 현장 사례에서 가이드 생성된 경우 사례 상태 업데이트
    if (widget.fromCase != null) {
      dataService.markCaseAsConverted(widget.fromCase!.id);
    }
    
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(publish ? '시나리오를 저장하고 공개했습니다.' : '시나리오를 초안으로 저장했습니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dataService = ref.watch(dataServiceProvider);
    
    return Scaffold(
      appBar: AppBar(title: Text(widget.fromCase != null ? '현장 사례 기반 시나리오 생성' : (widget.existing == null ? '시나리오 만들기' : '시나리오 수정'))),
      body: Form(
        key: formKey,
        child: content([
          if (widget.fromCase != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.amber, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '[현장 사례 가이드] 수습생(${widget.fromCase!.authorName})이 제보한 현장 사례 정보가 가이드 입력되었습니다. 내용을 검토 후 시나리오로 등록하세요.',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          const Text('연습 상황의 기본 정보와 직원이 따라야 할 필수/선택 대응 조치 기준을 입력하세요.'),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: industry,
            decoration: const InputDecoration(labelText: '업종 / 매장', border: OutlineInputBorder()),
            items: industries.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) => setState(() {
              industry = v ?? industry;
              selectedRules.clear();
            }),
          ),
          const SizedBox(height: 12),
          TextFormField(controller: title, validator: requiredText, decoration: const InputDecoration(labelText: '상황 제목', hintText: '예: 결제 오류 문의', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextFormField(controller: situation, validator: requiredText, minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: '상황 / 고객 발화', hintText: '고객이 어떤 상황에서 무엇을 요청하나요?', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          
          // 필수 대응 조치 입력창
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
          
          // 선택 대응 조치 입력창
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
          
          ExpansionTile(
            initiallyExpanded: selectedRules.isEmpty,
            title: Text('연결된 매장 운영규칙 (${selectedRules.length}개 선택)'),
            subtitle: const Text('레퍼런스에 정리된 업종별 운영규칙'),
            children: [
              for (final rule in dataService.rulesByIndustry[industry] ?? const <String>[])
                CheckboxListTile(
                  dense: true,
                  title: Text(rule),
                  value: selectedRules.contains(rule),
                  onChanged: (checked) => setState(() {
                    if (checked == true) { selectedRules.add(rule); } else { selectedRules.remove(rule); }
                  }),
                ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextFormField(controller: rules, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: '추가 매장 자체 규칙 (선택)', hintText: '위 목록에 없는 매장 고유 절차', border: OutlineInputBorder())),
              ),
            ],
          ),
          ExpansionTile(
            title: Text('근거 자료 연결 (${selectedReferences.length}개 선택)'),
            subtitle: const Text('법령·공식 지침·매장 자체 규칙을 구분해 연결합니다.'),
            children: [
              for (final ref in dataService.references)
                CheckboxListTile(
                  dense: true,
                  title: Text('${ref.code} · ${ref.name}'),
                  subtitle: Text('${ref.kind} · ${ref.scope}'),
                  value: selectedReferences.contains(ref.code),
                  onChanged: (checked) => setState(() {
                    if (checked == true) { selectedReferences.add(ref.code); } else { selectedReferences.remove(ref.code); }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 18),
          SwitchListTile(
            title: const Text('공개 상태'),
            subtitle: Text(published ? '공개됨 (수습생 연습 목록에 노출)' : '비공개 (초안으로 보관)'),
            value: published,
            onChanged: (v) => setState(() => published = v),
          ),
          const SizedBox(height: 16),
          
          // 단일 저장 버튼 (공개 스위치 상태에 반응)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => save(dataService, publish: published),
              icon: Icon(published ? Icons.publish_rounded : Icons.save_rounded),
              label: Text(
                published ? '시나리오 저장 및 공개' : '시나리오 저장 (초안)',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          const Text('법령 적용 대상은 영업신고 유형·사업장 규모 등 사실관계에 따라 달라질 수 있습니다. 법령·공식 지침과 매장 자체 절차를 구분해 검토하세요.'),
        ]),
      ),
    );
  }
}
