class RoleplayScenario {
  RoleplayScenario({
    required this.id,
    required this.industry,
    required this.title,
    required this.situation,
    required this.expectedActions,
    required this.linkedRules,
    this.referenceCodes = const [],
    this.isPublished = false,
  });

  factory RoleplayScenario.fromJson(Map<String, dynamic> json) {
    return RoleplayScenario(
      id: (json['id'] ?? '').toString(),
      industry: (json['industry'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      situation: (json['situation'] ?? '').toString(),
      expectedActions: (json['expected_actions'] ?? json['expectedActions'] ?? '').toString(),
      linkedRules: (json['linked_rules'] ?? json['linkedRules'] ?? '').toString(),
      referenceCodes: (json['reference_codes'] as List<dynamic>? ?? json['referenceCodes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      isPublished: (json['is_published'] ?? json['isPublished']) as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'industry': industry,
      'title': title,
      'situation': situation,
      'expected_actions': expectedActions,
      'linked_rules': linkedRules,
      'reference_codes': referenceCodes,
      'is_published': isPublished,
    };
  }

  String get mandatoryActions {
    if (!expectedActions.contains('[필수]')) {
      if (expectedActions.contains('[선택]')) {
        return expectedActions
            .split('[선택]')
            .first
            .replaceAll('[필수]', '')
            .replaceAll('[선택]', '')
            .trim();
      }
      return expectedActions
          .replaceAll('[필수]', '')
          .replaceAll('[선택]', '')
          .trim();
    }

    final match = RegExp(
      r'\[필수\]([\s\S]*?)(?=\[선택\]|$)',
      multiLine: true,
    ).firstMatch(expectedActions);
    final result = match?.group(1)?.trim() ?? expectedActions;
    return result.replaceAll('[필수]', '').replaceAll('[선택]', '').trim();
  }

  String get optionalActions {
    if (!expectedActions.contains('[선택]')) return '';

    final match = RegExp(
      r'\[선택\]([\s\S]*)$',
      multiLine: true,
    ).firstMatch(expectedActions);
    final result = match?.group(1)?.trim() ?? '';
    return result.replaceAll('[필수]', '').replaceAll('[선택]', '').trim();
  }

  final String id;
  String industry;
  String title;
  String situation;
  String expectedActions;
  String linkedRules;
  List<String> referenceCodes;
  bool isPublished;
}
