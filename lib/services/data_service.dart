import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/roleplay_scenario.dart';
import '../models/official_reference.dart';
import '../models/practice_report.dart';
import '../models/field_case.dart';
import '../models/user_model.dart';
import '../config/api_config.dart';

final dataServiceProvider = ChangeNotifierProvider<DataService>((ref) => DataService());

class DataService extends ChangeNotifier {
  List<RoleplayScenario> scenarioStore = [];
  List<OfficialReference> references = [];
  List<PracticeReport> practiceReports = [];
  List<FieldCase> fieldCaseStore = [];
  List<Map<String, String>> manualDocs = [];
  List<String> categories = ['음료/메뉴', '고객 서비스', '안전/비상대응', '위생/식품안전', 'POS/금전정산', '시설/장비관리'];
  Map<String, String> categoryIconMap = {};
  RoleplayScenario? currentRecommendedScenario;
  bool isLoaded = false;

  String? currentUserId;
  String? currentUserDbId;
  Set<String> readScenarioIds = {};
  Set<String> readReportIds = {};
  Set<String> reviewedCaseIds = {};

  final Map<String, int> _scenarioModTimes = {};
  final Map<String, int> _scenarioReadTimes = {};
  final Map<String, int> _traineeReportTimes = {};
  final Map<String, int> _adminUserCheckTimes = {};

  static const String _customScenariosKey = 'custom_local_scenarios';
  static const String _categoriesKey = 'custom_categories_store';
  static const String _categoryIconsKey = 'custom_category_icons_map';
  static const String _reportsKey = 'local_practice_reports';
  static const String _fieldCasesKey = 'local_field_cases';

  // 🔴 관리자용: DB에 새로 등록된 검토 대기(pending) 현장 사례 중 관리자가 열람하지 않은 항목 존재 여부 동적 연산
  bool get hasUnreadCaseReview {
    final pendingCases = fieldCaseStore.where(
      (c) => c.status == FieldCaseStatus.pending && !c.isConvertedToScenario
    ).toList();

    if (pendingCases.isEmpty) return false;
    return pendingCases.any((c) => !reviewedCaseIds.contains(c.id.trim()));
  }

  // 🔴 상황극 탭 알림: 공개된 시나리오 중 유저가 확인하지 않은(NEW) 항목이 남아있는 경우
  bool get hasUnreadNewScenario {
    final published = scenarioStore.where((s) => s.isPublished).toList();
    return published.any((s) => isScenarioNew(s.id));
  }

  // 🔴 리포트 탭 알림: 완료된 훈련 리포트 중 유저가 열람하지 않은(NEW 🔴) 항목이 남아있는 경우
  bool get hasUnreadReport {
    return practiceReports.any((r) => isReportNew(r.id));
  }

  void _initManualDocs() {
    manualDocs = [
      {'doc_id': '01_운영총칙', 'title': '운영 총칙', 'filename': '01_운영총칙.docx', 'type': '매장 매뉴얼 문서'},
      {'doc_id': '02_근무_및_인사규정', 'title': '근무 및 인사 규정', 'filename': '02_근무_및_인사규정.docx', 'type': '매장 매뉴얼 문서'},
      {'doc_id': '03_개점_및_마감_절차', 'title': '개점 및 마감 절차', 'filename': '03_개점_및_마감_절차.docx', 'type': '매장 매뉴얼 문서'},
      {'doc_id': '04_고객응대_및_서비스', 'title': '고객 응대 및 서비스', 'filename': '04_고객응대_및_서비스.docx', 'type': '매장 매뉴얼 문서'},
      {'doc_id': '05_음료_및_메뉴_제조기준', 'title': '음료 및 메뉴 제조 기준', 'filename': '05_음료_및_메뉴_제조기준.docx', 'type': '매장 매뉴얼 문서'},
      {'doc_id': '06_위생_및_식품안전', 'title': '위생 및 식품안전', 'filename': '06_위생_및_식품안전.docx', 'type': '매장 매뉴얼 문서'},
      {'doc_id': '07_재고_발주_검수', 'title': '재고·발주·검수 관리', 'filename': '07_재고_발주_검수.docx', 'type': '매장 매뉴얼 문서'},
      {'doc_id': '08_금전_pos_정산', 'title': '금전·POS·정산 관리', 'filename': '08_금전_POS_정산.docx', 'type': '매장 매뉴얼 문서'},
      {'doc_id': '09_시설_장비_관리', 'title': '시설 및 장비 관리', 'filename': '09_시설_장비_관리.docx', 'type': '매장 매뉴얼 문서'},
      {'doc_id': '10_안전_및_비상대응', 'title': '안전 및 비상 대응', 'filename': '10_안전_및_비상대응.docx', 'type': '매장 매뉴얼 문서'},
    ];
  }

  void _initDefaultReferences() {
    references = const [
      OfficialReference(
        code: 'REF_01',
        name: '식품위생법 제44조 (영업자 등의 준수사항)',
        kind: '법령',
        scope: '전국 휴게음식점 및 제과점, 일반음식점 공통 적용',
        url: 'https://www.law.go.kr/',
      ),
      OfficialReference(
        code: 'REF_02',
        name: '근로기준법 제54조 (휴게시간 규정)',
        kind: '법령',
        scope: '근로자 1인 이상 사업장 전체 적용 (4시간 근무 시 30분 휴게)',
        url: 'https://www.law.go.kr/',
      ),
      OfficialReference(
        code: 'REF_03',
        name: '식품 표시·광고에 관한 법률 (알레르기 유발물질 표시)',
        kind: '공식 지침',
        scope: '우유, 메밀, 땅콩, 대두 등 22개 알레르기 원재료 표시 의무',
        url: 'https://www.mfds.go.kr/',
      ),
      OfficialReference(
        code: 'REF_04',
        name: '산업안전보건법 (조리·제조 시설 화상 및 미끄럼 방지 지침)',
        kind: '공식 지침',
        scope: '매장 조리 장비 가동 및 위생·안전 수칙 준수',
        url: 'https://www.kosha.or.kr/',
      ),
      OfficialReference(
        code: 'REF_05',
        name: '여신전문금융업법 (POS 중복결제 및 현금영수증 처리)',
        kind: '공식 지침',
        scope: '카드 결제 취소 및 재결제, 영수증 발급 수칙',
        url: 'https://www.fss.or.kr/',
      ),
    ];
  }

  // 로컬 초기화 및 백엔드 DB 레퍼런스/시나리오/카테고리 패치
  Future<void> loadData({String? baseUrl}) async {
    if (isLoaded) return;

    _initManualDocs();
    await _loadInitialAssets();
    await _loadFromLocalPrefs();

    final targetUrl = (baseUrl != null && baseUrl.isNotEmpty) ? baseUrl : ApiConfig.backendUrl;
    await _fetchScenariosInternal(targetUrl);
    await _fetchReferencesInternal(targetUrl);
    await _fetchManualDocsInternal(targetUrl);
    await _fetchCategoriesInternal(targetUrl);

    isLoaded = true;
    updateRecommendedScenario(forceReshuffle: false);
    notifyListeners();
  }

  Future<void> _loadInitialAssets() async {
    try {
      final scString = await rootBundle.loadString('assets/data/scenarios.json');
      final List<dynamic> scJson = jsonDecode(scString);
      scenarioStore = scJson.map((j) => RoleplayScenario.fromJson(j)).toList();
    } catch (e) {
      debugPrint('에셋 데이터 로드 예외: $e');
    }
  }

  IconData getCategoryIcon(String category) {
    if (categoryIconMap.containsKey(category)) {
      final iconName = categoryIconMap[category];
      final parsed = _parseIconData(iconName);
      if (parsed != null) return parsed;
    }
    return autoMatchCategoryIcon(category);
  }

  static IconData autoMatchCategoryIcon(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('음료') || cat.contains('카페') || cat.contains('커피')) return Icons.local_cafe_outlined;
    if (cat.contains('서비스') || cat.contains('고객') || cat.contains('응대')) return Icons.sentiment_satisfied_alt_outlined;
    if (cat.contains('안전') || cat.contains('비상') || cat.contains('사고')) return Icons.health_and_safety_outlined;
    if (cat.contains('위생') || cat.contains('식품') || cat.contains('청결')) return Icons.sanitizer_outlined;
    if (cat.contains('pos') || cat.contains('정산') || cat.contains('금전') || cat.contains('결제')) return Icons.point_of_sale_outlined;
    if (cat.contains('시설') || cat.contains('장비') || cat.contains('머신') || cat.contains('점검')) return Icons.build_circle_outlined;
    if (cat.contains('배달') || cat.contains('포장') || cat.contains('택배')) return Icons.local_shipping_outlined;
    if (cat.contains('이벤트') || cat.contains('행사') || cat.contains('쿠폰')) return Icons.card_giftcard_outlined;
    if (cat.contains('청소') || cat.contains('환경') || cat.contains('마감')) return Icons.cleaning_services_outlined;
    if (cat.contains('재고') || cat.contains('발주') || cat.contains('검수')) return Icons.inventory_2_outlined;
    if (cat.contains('메뉴') || cat.contains('조리') || cat.contains('요리')) return Icons.restaurant_outlined;
    return Icons.category_outlined;
  }

  static IconData? _parseIconData(String? name) {
    return switch (name) {
      'local_cafe' => Icons.local_cafe_outlined,
      'sentiment_satisfied' => Icons.sentiment_satisfied_alt_outlined,
      'health_and_safety' => Icons.health_and_safety_outlined,
      'sanitizer' => Icons.sanitizer_outlined,
      'point_of_sale' => Icons.point_of_sale_outlined,
      'build_circle' => Icons.build_circle_outlined,
      'local_shipping' => Icons.local_shipping_outlined,
      'card_giftcard' => Icons.card_giftcard_outlined,
      'inventory_2' => Icons.inventory_2_outlined,
      'restaurant' => Icons.restaurant_outlined,
      'cleaning_services' => Icons.cleaning_services_outlined,
      'assignment' => Icons.assignment_outlined,
      'access_time' => Icons.access_time_outlined,
      'campaign' => Icons.campaign_outlined,
      'attach_money' => Icons.attach_money_outlined,
      'category' => Icons.category_outlined,
      _ => null,
    };
  }

  Future<void> _saveToLocalPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_customScenariosKey, jsonEncode(scenarioStore.map((s) => s.toJson()).toList()));
      await prefs.setString(_categoriesKey, jsonEncode(categories));
      await prefs.setString(_categoryIconsKey, jsonEncode(categoryIconMap));
      await prefs.setString(_reportsKey, jsonEncode(practiceReports.map((r) => r.toJson()).toList()));
      await prefs.setString(_fieldCasesKey, jsonEncode(fieldCaseStore.map((c) => c.toJson()).toList()));
    } catch (e) {
      debugPrint('로컬 저장소 영구 보관 실패: $e');
    }
  }

  Future<void> _loadFromLocalPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final savedScStr = prefs.getString(_customScenariosKey);
      if (savedScStr != null && savedScStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(savedScStr);
        final localScenarios = list.map((j) => RoleplayScenario.fromJson(j)).toList();
        final Map<String, RoleplayScenario> map = {for (var s in scenarioStore) s.id: s};
        for (final s in localScenarios) {
          map[s.id] = s;
        }
        scenarioStore = map.values.toList();
      }

      final savedCatStr = prefs.getString(_categoriesKey);
      if (savedCatStr != null && savedCatStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(savedCatStr);
        categories = list.map((e) => e.toString()).toList();
      }

      final savedIconStr = prefs.getString(_categoryIconsKey);
      if (savedIconStr != null && savedIconStr.isNotEmpty) {
        final Map<String, dynamic> iconJson = jsonDecode(savedIconStr);
        categoryIconMap = iconJson.map((k, v) => MapEntry(k, v.toString()));
      }

      final savedRepStr = prefs.getString(_reportsKey);
      if (savedRepStr != null && savedRepStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(savedRepStr);
        practiceReports = list.map((j) => PracticeReport.fromJson(j)).toList();
      }

      final savedCaseStr = prefs.getString(_fieldCasesKey);
      if (savedCaseStr != null && savedCaseStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(savedCaseStr);
        fieldCaseStore = list.map((j) => FieldCase.fromJson(j)).toList();
      }
    } catch (e) {
      debugPrint('로컬 저장소 로드 실패: $e');
    }
  }

  // --- 백엔드 DB 연동 로직 ---
  Future<void> fetchReportsFromBackend(String? token, String? baseUrl) async {
    if (token != null && token.isNotEmpty && baseUrl != null && baseUrl.isNotEmpty) {
      await _fetchReportsInternal(token, baseUrl);
      notifyListeners();
    }
  }

  Future<void> _fetchReportsInternal(String token, String baseUrl) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/me/reports'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(utf8.decode(response.bodyBytes));
        final serverReports = jsonList.map((j) => PracticeReport.fromJson(j)).toList();
        
        // 로컬 리포트와 병합
        final Map<String, PracticeReport> map = {for (var r in practiceReports) r.id: r};
        for (final r in serverReports) {
          map[r.id] = r;
        }
        practiceReports = map.values.toList();
        practiceReports.sort((a, b) => b.dateTime.compareTo(a.dateTime));
        _saveToLocalPrefs();
      }
    } catch (e) {
      debugPrint('백엔드 훈련 리포트 동기화 실패: $e');
    }
  }

  Future<void> fetchFieldCasesFromBackend(String? token, String? baseUrl) async {
    if (token != null && token.isNotEmpty && baseUrl != null && baseUrl.isNotEmpty) {
      await _fetchFieldCasesInternal(token, baseUrl);
      notifyListeners();
    }
  }

  Future<void> _fetchFieldCasesInternal(String token, String baseUrl) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/cases'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(utf8.decode(response.bodyBytes));
        final serverCases = jsonList.map((j) => FieldCase.fromJson(j)).toList();
        
        final Map<String, FieldCase> map = {for (var c in fieldCaseStore) c.id: c};
        for (final c in serverCases) {
          map[c.id] = c;
        }
        fieldCaseStore = map.values.toList();
        fieldCaseStore.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _saveToLocalPrefs();
      }
    } catch (e) {
      debugPrint('백엔드 현장 사례 동기화 실패: $e');
    }
  }

  Future<void> _fetchReferencesInternal(String baseUrl) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/scenarios/references'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(utf8.decode(response.bodyBytes));
        final serverRefs = jsonList.map((j) => OfficialReference.fromJson(j)).toList();
        if (serverRefs.isNotEmpty) {
          references = serverRefs;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('백엔드 레퍼런스 동기화 실패: $e');
    }
  }

  Future<void> _fetchScenariosInternal(String baseUrl) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/scenarios'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(utf8.decode(response.bodyBytes));
        final serverScenarios = jsonList.map((j) => RoleplayScenario.fromJson(j)).toList();
        final Map<String, RoleplayScenario> map = {for (var s in scenarioStore) s.id: s};
        for (final s in serverScenarios) {
          map[s.id] = s;
        }
        scenarioStore = map.values.toList();
        _saveToLocalPrefs();
      }
    } catch (e) {
      debugPrint('백엔드 시나리오 동기화 실패: $e');
    }
  }

  Future<void> _fetchCategoriesInternal(String baseUrl) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/scenarios/categories'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(utf8.decode(response.bodyBytes));
        final fetched = jsonList.map((j) => (j['name'] ?? '').toString()).where((s) => s.isNotEmpty).toList();
        if (fetched.isNotEmpty) {
          for (final f in fetched) {
            if (!categories.contains(f)) {
              categories.add(f);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('백엔드 카테고리 동기화 실패: $e');
    }
  }

  Future<void> _fetchManualDocsInternal(String baseUrl) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/docs/list'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(utf8.decode(response.bodyBytes));
        if (jsonList.isNotEmpty) {
          manualDocs = jsonList.map((j) => {
            'doc_id': (j['doc_id'] ?? '').toString(),
            'title': (j['title'] ?? '매장 매뉴얼').toString(),
            'filename': (j['filename'] ?? '').toString(),
            'type': (j['type'] ?? '매뉴얼 문서').toString(),
          }).toList();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('백엔드 매뉴얼 문서 목록 동기화 실패: $e');
    }
  }

  // 🔴 현재 유저별 알림 동기화
  Future<void> syncUserNotifications(String userId, {bool isAdmin = false, String? userDbId}) async {
    currentUserId = userId;
    currentUserDbId = userDbId;
    final prefs = await SharedPreferences.getInstance();

    _scenarioModTimes.clear();
    _scenarioReadTimes.clear();

    for (final s in scenarioStore) {
      _scenarioModTimes[s.id] = prefs.getInt('scenario_mod_time_${s.id}') ?? 0;
      _scenarioReadTimes[s.id] = prefs.getInt('scenario_read_time_${userId}_${s.id}') ?? 0;
    }

    if (isAdmin) {
      _traineeReportTimes.clear();
      _adminUserCheckTimes.clear();
      for (final key in prefs.getKeys()) {
        if (key.startsWith('last_report_completed_time_')) {
          final targetUid = key.replaceFirst('last_report_completed_time_', '');
          _traineeReportTimes[targetUid] = prefs.getInt(key) ?? 0;
          _adminUserCheckTimes[targetUid] = prefs.getInt('admin_check_time_${userId}_$targetUid') ?? 0;
        }
      }

      final reviewedList = prefs.getStringList('reviewed_case_ids_$userId');
      if (reviewedList != null) {
        reviewedCaseIds = reviewedList.toSet();
      } else {
        reviewedCaseIds = {};
      }
    }

    final readList = prefs.getStringList('read_scenarios_$userId');
    readScenarioIds = readList != null ? readList.toSet() : {};

    final readReportList = prefs.getStringList('read_reports_$userId');
    readReportIds = readReportList != null ? readReportList.toSet() : {};

    updateRecommendedScenario(forceReshuffle: false);
    notifyListeners();
  }

  bool isScenarioNew(String scenarioId) {
    if (currentUserId == null) return false;
    if (!readScenarioIds.contains(scenarioId)) return true;
    final modTime = _scenarioModTimes[scenarioId] ?? 0;
    final readTime = _scenarioReadTimes[scenarioId] ?? 0;
    return modTime > readTime;
  }

  void markScenarioAsRead(String scenarioId) async {
    if (currentUserId == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    _scenarioReadTimes[scenarioId] = now;
    readScenarioIds.add(scenarioId);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('scenario_read_time_${currentUserId}_$scenarioId', now);
    await prefs.setStringList('read_scenarios_$currentUserId', readScenarioIds.toList());
    notifyListeners();
  }

  bool isReportNew(String reportId) {
    if (currentUserId == null) return false;
    return !readReportIds.contains(reportId.trim());
  }

  bool isScenarioReportsNew(String scenarioId) {
    final reports = getReportsForScenario(scenarioId);
    return reports.any((r) => isReportNew(r.id));
  }

  void markReportsAsReadForScenario(String scenarioId) {
    final reports = getReportsForScenario(scenarioId);
    for (final r in reports) {
      markReportAsRead(r.id);
    }
  }

  void markReportAsRead(String reportId) async {
    if (currentUserId == null) return;
    readReportIds.add(reportId.trim());

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('read_reports_$currentUserId', readReportIds.toList());
    notifyListeners();
  }

  bool isTraineeReportNew(String traineeUserId) {
    if (currentUserId == null) return false;
    final lastReportTime = _traineeReportTimes[traineeUserId] ?? 0;
    final lastCheckTime = _adminUserCheckTimes[traineeUserId] ?? 0;
    return lastReportTime > lastCheckTime;
  }

  bool hasUnreadAdminUserReports(List<UserModel> users) {
    return users.any((u) => isTraineeReportNew(u.id));
  }

  void markTraineeReportAsInspected(String traineeUserId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    _adminUserCheckTimes[traineeUserId] = now;
    if (currentUserId != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('admin_check_time_${currentUserId}_$traineeUserId', now);
    }
    notifyListeners();
  }

  void clearCaseReviewNotification() async {
    final pendingCases = fieldCaseStore.where(
      (c) => c.status == FieldCaseStatus.pending && !c.isConvertedToScenario
    ).toList();

    bool changed = false;
    for (final c in pendingCases) {
      if (reviewedCaseIds.add(c.id.trim())) {
        changed = true;
      }
    }

    if (changed || pendingCases.isEmpty) {
      notifyListeners();
      if (currentUserId != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('reviewed_case_ids_$currentUserId', reviewedCaseIds.toList());
      }
    }
  }

  // --- 시나리오 관리 CRUD ---
  void addScenario(RoleplayScenario scenario, {String? token, String? baseUrl, String? creatorId}) async {
    scenarioStore.add(scenario);
    final now = DateTime.now().millisecondsSinceEpoch;
    _scenarioModTimes[scenario.id] = now;
    _saveToLocalPrefs();
    updateRecommendedScenario(forceReshuffle: false);
    notifyListeners();

    if (token != null && token.isNotEmpty && baseUrl != null && baseUrl.isNotEmpty) {
      try {
        await http.post(
          Uri.parse('$baseUrl/scenarios'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(scenario.toJson()),
        ).timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint('백엔드 시나리오 저장 실패: $e');
      }
    }
  }

  void updateScenario(RoleplayScenario scenario, {String? token, String? baseUrl, String? creatorId}) async {
    final index = scenarioStore.indexWhere((s) => s.id == scenario.id);
    if (index != -1) {
      scenarioStore[index] = scenario;
      final now = DateTime.now().millisecondsSinceEpoch;
      _scenarioModTimes[scenario.id] = now;
      _saveToLocalPrefs();
      updateRecommendedScenario(forceReshuffle: false);
      notifyListeners();

      if (token != null && token.isNotEmpty && baseUrl != null && baseUrl.isNotEmpty) {
        try {
          await http.put(
            Uri.parse('$baseUrl/scenarios/${scenario.id}'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(scenario.toJson()),
          ).timeout(const Duration(seconds: 4));
        } catch (e) {
          debugPrint('백엔드 시나리오 수정 실패: $e');
        }
      }
    }
  }

  void toggleScenarioPublished(String scenarioId, {String? token, String? baseUrl}) async {
    final index = scenarioStore.indexWhere((s) => s.id == scenarioId);
    if (index != -1) {
      scenarioStore[index].isPublished = !scenarioStore[index].isPublished;
      _saveToLocalPrefs();
      updateRecommendedScenario(forceReshuffle: false);
      notifyListeners();

      if (token != null && token.isNotEmpty && baseUrl != null && baseUrl.isNotEmpty) {
        try {
          await http.put(
            Uri.parse('$baseUrl/scenarios/$scenarioId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(scenarioStore[index].toJson()),
          ).timeout(const Duration(seconds: 4));
        } catch (e) {
          debugPrint('백엔드 시나리오 토글 실패: $e');
        }
      }
    }
  }

  void removeScenario(String scenarioId, {String? token, String? baseUrl}) async {
    scenarioStore.removeWhere((s) => s.id == scenarioId);
    _saveToLocalPrefs();
    updateRecommendedScenario(forceReshuffle: false);
    notifyListeners();

    if (token != null && token.isNotEmpty && baseUrl != null && baseUrl.isNotEmpty) {
      try {
        await http.delete(
          Uri.parse('$baseUrl/scenarios/$scenarioId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint('백엔드 시나리오 삭제 실패: $e');
      }
    }
  }

  // --- 카테고리 관리 ---
  Future<bool> addCategory(String name, {String? iconName, String? token, String? baseUrl}) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return false;
    if (!categories.contains(cleanName)) {
      categories.add(cleanName);
    }
    if (iconName != null && iconName.isNotEmpty) {
      categoryIconMap[cleanName] = iconName;
    }
    _saveToLocalPrefs();
    notifyListeners();

    if (token != null && token.isNotEmpty && baseUrl != null && baseUrl.isNotEmpty) {
      try {
        await http.post(
          Uri.parse('$baseUrl/scenarios/categories'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'name': cleanName}),
        ).timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint('백엔드 카테고리 추가 실패: $e');
      }
    }
    return true;
  }

  Future<bool> deleteCategory(String name, {String? token, String? baseUrl}) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return false;
    categories.remove(cleanName);
    categoryIconMap.remove(cleanName);
    _saveToLocalPrefs();
    notifyListeners();

    if (token != null && token.isNotEmpty && baseUrl != null && baseUrl.isNotEmpty) {
      try {
        await http.delete(
          Uri.parse('$baseUrl/scenarios/categories/${Uri.encodeComponent(cleanName)}'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint('백엔드 카테고리 삭제 실패: $e');
      }
    }
    return true;
  }

  // --- 훈련 리포트 CRUD ---
  void addPracticeReport(PracticeReport report, {String? token, String? baseUrl}) async {
    final index = practiceReports.indexWhere((r) => r.id.trim() == report.id.trim());
    if (index != -1) {
      practiceReports[index] = report;
    } else {
      practiceReports.insert(0, report);
    }
    _saveToLocalPrefs();
    notifyListeners();

    if (token != null && token.isNotEmpty && baseUrl != null && baseUrl.isNotEmpty) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/users/me/reports'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(report.toBackendJson()),
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 201) {
          debugPrint('백엔드 DB에 훈련 리포트 저장 성공!');
          await _fetchReportsInternal(token, baseUrl);
        }
      } catch (e) {
        debugPrint('백엔드 훈련 리포트 저장 실패: $e');
      }
    }
  }

  void addReport(PracticeReport report, {String? token, String? baseUrl}) => addPracticeReport(report, token: token, baseUrl: baseUrl);

  void setAdminReportComment(String reportId, String comment, String targetUserId, {String? token, String? baseUrl}) async {
    final index = practiceReports.indexWhere((r) => r.id == reportId);
    if (index != -1) {
      practiceReports[index].adminComment = comment.trim();
      _saveToLocalPrefs();
      notifyListeners();

      if (token != null && token.isNotEmpty && baseUrl != null && baseUrl.isNotEmpty) {
        try {
          final int reportDbId = int.tryParse(reportId) ?? -1;
          if (reportDbId > 0) {
            await http.put(
              Uri.parse('$baseUrl/admin/reports/$reportDbId/comment'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode({'admin_comment': comment.trim()}),
            ).timeout(const Duration(seconds: 4));
          }
        } catch (e) {
          debugPrint('백엔드 관리자 코멘트 저장 실패: $e');
        }
      }
    }
  }

  void deleteReport(String reportId, {String? token, String? baseUrl}) async {
    practiceReports.removeWhere((r) => r.id == reportId);
    _saveToLocalPrefs();
    notifyListeners();

    if (token != null && token.isNotEmpty && baseUrl != null && baseUrl.isNotEmpty) {
      try {
        final int reportDbId = int.tryParse(reportId) ?? -1;
        if (reportDbId > 0) {
          await http.delete(
            Uri.parse('$baseUrl/admin/reports/$reportDbId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          ).timeout(const Duration(seconds: 4));
        }
      } catch (e) {
        debugPrint('백엔드 리포트 삭제 실패: $e');
      }
    }
  }

  List<PracticeReport> get currentUserReports {
    if (currentUserId == null || currentUserId!.trim().isEmpty) return [];
    final uid = currentUserId!.trim();
    final dbIdStr = currentUserDbId?.trim() ?? '';

    // 💡 DB user_id(정수 PK 또는 문자열 계정 ID)와 100% 엄격 대조된 본인 리포트만 반환
    return practiceReports.where((r) {
      final rUid = r.userId.trim();
      if (rUid.isEmpty) return false;
      return rUid == uid || (dbIdStr.isNotEmpty && rUid == dbIdStr);
    }).toList();
  }

  List<PracticeReport> getReportsForScenario(String scenarioId) {
    return currentUserReports.where((r) => r.scenarioId == scenarioId).toList();
  }

  Map<String, List<PracticeReport>> get groupedReports {
    final Map<String, List<PracticeReport>> grouped = {};
    for (final report in currentUserReports) {
      grouped.putIfAbsent(report.scenarioId, () => []).add(report);
    }
    return grouped;
  }

  List<PracticeReport> get lowScoreLatestReports {
    final latestMap = <String, PracticeReport>{};
    for (final report in currentUserReports) {
      if (!latestMap.containsKey(report.scenarioId) ||
          report.dateTime.isAfter(latestMap[report.scenarioId]!.dateTime)) {
        latestMap[report.scenarioId] = report;
      }
    }
    return latestMap.values.where((r) => r.score < 80).toList();
  }

  // --- 현장 사례 CRUD ---
  void addFieldCase(FieldCase fieldCase, {String? token, String? baseUrl}) async {
    fieldCaseStore.insert(0, fieldCase);
    fieldCaseStore.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _saveToLocalPrefs();
    notifyListeners();

    if (token != null && token.isNotEmpty && baseUrl != null && baseUrl.isNotEmpty) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/cases'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(fieldCase.toBackendJson()),
        ).timeout(const Duration(seconds: 4));

        if (response.statusCode == 201) {
          debugPrint('백엔드 DB에 신규 현장 사례 저장 성공!');
          await _fetchFieldCasesInternal(token, baseUrl);
        }
      } catch (e) {
        debugPrint('백엔드 현장 사례 저장 실패: $e');
      }
    }
  }

  void deleteFieldCase(String caseId, {String? token, String? baseUrl}) async {
    fieldCaseStore.removeWhere((c) => c.id == caseId);
    _saveToLocalPrefs();
    notifyListeners();

    if (token != null && token.isNotEmpty && baseUrl != null && baseUrl.isNotEmpty) {
      try {
        await http.delete(
          Uri.parse('$baseUrl/cases/$caseId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint('백엔드 현장 사례 삭제 실패: $e');
      }
    }
  }

  void markCaseAsConverted(String caseId, {String? token, String? baseUrl}) async {
    final index = fieldCaseStore.indexWhere((c) => c.id == caseId);
    if (index != -1) {
      fieldCaseStore[index].status = FieldCaseStatus.approved;
      fieldCaseStore[index].isConvertedToScenario = true;
      _saveToLocalPrefs();
      notifyListeners();

      if (token != null && token.isNotEmpty && baseUrl != null && baseUrl.isNotEmpty) {
        try {
          await http.put(
            Uri.parse('$baseUrl/cases/$caseId/convert'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          ).timeout(const Duration(seconds: 4));
        } catch (e) {
          debugPrint('백엔드 현장 사례 변환 마킹 실패: $e');
        }
      }
    }
  }

  void clearUserData() {
    practiceReports.clear();
    fieldCaseStore.clear();
    readScenarioIds.clear();
    readReportIds.clear();
    reviewedCaseIds.clear();
    _scenarioModTimes.clear();
    _scenarioReadTimes.clear();
    _traineeReportTimes.clear();
    _adminUserCheckTimes.clear();
    currentUserId = null;
    currentRecommendedScenario = null;
    isLoaded = false;
    notifyListeners();
  }

  Future<void> refreshData({String? token, String? baseUrl}) async {
    final targetUrl = (baseUrl != null && baseUrl.isNotEmpty) ? baseUrl : ApiConfig.backendUrl;
    await _fetchScenariosInternal(targetUrl);
    await _fetchReferencesInternal(targetUrl);
    await _fetchManualDocsInternal(targetUrl);
    await _fetchCategoriesInternal(targetUrl);

    if (token != null && token.isNotEmpty) {
      await _fetchReportsInternal(token, targetUrl);
      await _fetchFieldCasesInternal(token, targetUrl);
    }

    updateRecommendedScenario(forceReshuffle: true);
    notifyListeners();
  }

  void updateRecommendedScenario({bool forceReshuffle = false}) {
    final published = scenarioStore.where((s) => s.isPublished).toList();
    if (published.isEmpty) {
      currentRecommendedScenario = null;
      return;
    }
    if (currentRecommendedScenario == null || forceReshuffle) {
      currentRecommendedScenario = published.first;
    }
  }
}
