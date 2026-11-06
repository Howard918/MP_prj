import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/roleplay_scenario.dart';
import '../models/official_reference.dart';
import '../models/practice_report.dart';
import '../models/field_case.dart';
import '../models/user_model.dart';
import '../utils/server_connection_handler.dart';

final dataServiceProvider = ChangeNotifierProvider<DataService>((ref) => DataService());

class DataService extends ChangeNotifier {
  List<RoleplayScenario> scenarioStore = [];
  List<OfficialReference> references = [];
  Map<String, List<String>> rulesByIndustry = {};
  List<PracticeReport> practiceReports = [];
  List<FieldCase> fieldCaseStore = [];
  RoleplayScenario? currentRecommendedScenario;
  bool isLoaded = false;

  String? currentUserId;
  Set<String> readScenarioIds = {}; // 현재 유저가 개별 확인/수행한 시나리오 ID 목록
  Set<String> readReportIds = {}; // 현재 유저가 개별 확인/열람한 훈련 리포트 ID 목록
  final Map<String, int> _scenarioModTimes = {};
  final Map<String, int> _scenarioReadTimes = {};

  final Map<String, int> _traineeReportTimes = {};
  final Map<String, int> _adminUserCheckTimes = {};

  static const String _customScenariosKey = 'custom_local_scenarios';

  // 🔴 각 유저별 독립된 빨간 닷 알림 상태
  bool hasUnreadCaseReview = false; // 관리자용: 신규 현장 사례 제출 알림 (관리자 탭 🔴)

  // 🔴 상황극 탭 알림: 공개된 시나리오 중 유저가 확인하지 않은(NEW) 항목이 1개라도 남아있는 경우 동적 연산
  bool get hasUnreadNewScenario {
    final published = scenarioStore.where((s) => s.isPublished).toList();
    return published.any((s) => isScenarioNew(s.id));
  }

  // 🔴 리포트 탭 알림: 완료된 훈련 리포트 중 유저가 열람하지 않은(NEW 🔴) 리포트가 1개라도 남아있는 경우 동적 연산
  bool get hasUnreadReport {
    return practiceReports.any((r) => isReportNew(r.id));
  }

  // 로컬 저장소에 시나리오 변경 사항 영구 보관 (기본 에셋 초기화 방지)
  Future<void> _saveScenariosToLocalPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = scenarioStore.map((s) => s.toJson()).toList();
      await prefs.setString(_customScenariosKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('로컬 시나리오 영구 저장 실패: $e');
    }
  }

  // 로컬 저장소에서 변경된 시나리오 로드하여 에셋 기본값 오버라이드
  Future<void> _loadScenariosFromLocalPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedStr = prefs.getString(_customScenariosKey);
      if (savedStr != null && savedStr.isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(savedStr);
        final localScenarios = jsonList.map((j) => RoleplayScenario.fromJson(j)).toList();

        final Map<String, RoleplayScenario> map = {};
        for (final s in scenarioStore) {
          map[s.id] = s;
        }
        for (final s in localScenarios) {
          map[s.id] = s;
        }
        scenarioStore = map.values.toList();
      }
    } catch (e) {
      debugPrint('로컬 시나리오 저장소 로드 실패: $e');
    }
  }

  // 🔴 현재 유저별 타임스탬프 및 개별 읽은 시나리오/리포트 동기화 및 로드
  Future<void> syncUserNotifications(String userId, {bool isAdmin = false}) async {
    currentUserId = userId;
    final prefs = await SharedPreferences.getInstance();

    _scenarioModTimes.clear();
    _scenarioReadTimes.clear();

    for (final s in scenarioStore) {
      _scenarioModTimes[s.id] = prefs.getInt('scenario_mod_time_${s.id}') ?? 0;
      _scenarioReadTimes[s.id] = prefs.getInt('scenario_read_time_${userId}_${s.id}') ?? 0;
    }

    // 관리자용 수습생 유저 훈련 리포트 확인 타임스탬프 동기화
    if (isAdmin) {
      _traineeReportTimes.clear();
      _adminUserCheckTimes.clear();
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith('last_report_completed_time_')) {
          final targetUid = key.replaceFirst('last_report_completed_time_', '');
          _traineeReportTimes[targetUid] = prefs.getInt(key) ?? 0;
          _adminUserCheckTimes[targetUid] = prefs.getInt('admin_check_time_${userId}_$targetUid') ?? 0;
        }
      }
    }

    // 1. 개별 확인된 시나리오 ID 세트 로드
    final readList = prefs.getStringList('read_scenarios_$userId');
    if (readList != null) {
      readScenarioIds = readList.toSet();
    } else {
      if (scenarioStore.isNotEmpty) {
        readScenarioIds = scenarioStore.map((s) => s.id).toSet();
        await prefs.setStringList('read_scenarios_$userId', readScenarioIds.toList());
        final now = DateTime.now().millisecondsSinceEpoch;
        for (final s in scenarioStore) {
          _scenarioReadTimes[s.id] = now;
          await prefs.setInt('scenario_read_time_${userId}_${s.id}', now);
        }
      } else {
        readScenarioIds = {};
      }
    }

    // 2. 개별 확인된 훈련 리포트 ID 세트 로드
    final readReportList = prefs.getStringList('read_reports_$userId');
    if (readReportList != null) {
      readReportIds = readReportList.toSet();
    } else {
      if (practiceReports.isNotEmpty) {
        readReportIds = practiceReports.map((r) => r.id.trim()).toSet();
        await prefs.setStringList('read_reports_$userId', readReportIds.toList());
      } else {
        readReportIds = {};
      }
    }

    // 3. 관리자 전용 신규 현장 사례 검토 알림 확인
    if (isAdmin) {
      final lastCaseSubmitTime = prefs.getInt('last_case_submitted_time') ?? 0;
      final lastCaseCheckTime = prefs.getInt('last_case_review_checked_time_$userId') ?? 0;

      if (lastCaseSubmitTime > lastCaseCheckTime) {
        hasUnreadCaseReview = true;
      } else {
        hasUnreadCaseReview = false;
      }
    } else {
      hasUnreadCaseReview = false;
    }

    updateRecommendedScenario(forceReshuffle: false);
    notifyListeners();
  }

  // 🔴 관리자용: 특정 수습생 유저가 새 상황극 훈련을 완수했는지(NEW 🔴) 판별
  bool isTraineeReportNew(String traineeUserId) {
    if (currentUserId == null) return false;
    final lastReportTime = _traineeReportTimes[traineeUserId] ?? 0;
    final lastCheckTime = _adminUserCheckTimes[traineeUserId] ?? 0;
    return lastReportTime > lastCheckTime;
  }

  // 🔴 관리자용: 전체 유저 목록 중 새로운 훈련 진행 데이터가 존재하는지 판별
  bool hasUnreadAdminUserReports(List<UserModel> users) {
    return users.any((u) => isTraineeReportNew(u.id));
  }

  // 🔴 관리자용: 특정 유저의 [진행 데이터 열람] 버튼 클릭 시 읽음 처리
  void markTraineeReportAsInspected(String traineeUserId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    _adminUserCheckTimes[traineeUserId] = now;
    notifyListeners();

    if (currentUserId != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('admin_check_time_${currentUserId}_$traineeUserId', now);
    }
  }

  // 🔴 개별 시나리오 항목의 읽음/안읽음(NEW 🔴) 판별
  bool isScenarioNew(String scenarioId) {
    if (!readScenarioIds.contains(scenarioId)) return true;
    final modTime = _scenarioModTimes[scenarioId] ?? 0;
    final readTime = _scenarioReadTimes[scenarioId] ?? 0;
    if (modTime > 0 && modTime > readTime) return true;
    return false;
  }

  // 🔴 특정 시나리오 항목을 클릭하여 확인 처리 (해당 시나리오 및 남은 안읽은 시나리오 존재 여부에 따라 탭 빨간 닷 자동 갱신)
  void markScenarioAsRead(String scenarioId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    readScenarioIds.add(scenarioId);
    _scenarioReadTimes[scenarioId] = now;
    notifyListeners();

    if (currentUserId != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('read_scenarios_$currentUserId', readScenarioIds.toList());
      await prefs.setInt('scenario_read_time_${currentUserId}_$scenarioId', now);
    }
  }

  // 🔴 개별 훈련 리포트 항목의 안읽음(NEW 🔴) 판별
  bool isReportNew(String reportId) {
    return !readReportIds.contains(reportId.trim());
  }

  // 🔴 특정 시나리오에 묶인 리포트 중 안읽은 리포트가 1개라도 존재하는지 판별
  bool isScenarioReportsNew(String scenarioId) {
    final reports = getReportsForScenario(scenarioId);
    return reports.any((r) => isReportNew(r.id));
  }

  // 🔴 특정 훈련 리포트 항목을 직접 클릭/열람하여 읽음 처리
  void markReportAsRead(String reportId) async {
    final trimmedId = reportId.trim();
    if (readReportIds.add(trimmedId)) {
      notifyListeners();
      if (currentUserId != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('read_reports_$currentUserId', readReportIds.toList());
      }
    }
  }

  // 🔴 특정 시나리오에 묶인 모든 리포트 읽음 처리
  void markReportsAsReadForScenario(String scenarioId) async {
    final reports = getReportsForScenario(scenarioId);
    bool changed = false;
    for (final r in reports) {
      if (readReportIds.add(r.id.trim())) {
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
      if (currentUserId != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('read_reports_$currentUserId', readReportIds.toList());
      }
    }
  }

  // 🔴 특정 유저의 리포트를 안읽음(NEW 🔴)으로 전환 (새 훈련 완료 또는 관리자 코멘트 작성/수정 시)
  void invalidateReadReportForUser(String reportId, String targetUserId) async {
    final trimmedId = reportId.trim();
    if (currentUserId == targetUserId) {
      readReportIds.remove(trimmedId);
    }
    final prefs = await SharedPreferences.getInstance();
    final targetReadList = prefs.getStringList('read_reports_$targetUserId') ?? [];
    targetReadList.remove(trimmedId);
    await prefs.setStringList('read_reports_$targetUserId', targetReadList);

    final now = DateTime.now().millisecondsSinceEpoch;
    _traineeReportTimes[targetUserId] = now;
    await prefs.setInt('last_report_completed_time_$targetUserId', now);
    notifyListeners();
  }

  // 사례 검토 알림 확인/해제 (현재 유저/관리자 전용 타임스탬프 갱신)
  void clearCaseReviewNotification() async {
    hasUnreadCaseReview = false;
    notifyListeners();
    if (currentUserId != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_case_review_checked_time_$currentUserId', DateTime.now().millisecondsSinceEpoch);
    }
  }

  // 관리자 유저들에게 신규 현장 사례 검토 알림 전송 🔴
  Future<void> triggerCaseReviewNotification(String authorId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_case_submitted_time', now);
    await prefs.setString('last_case_submitter_id', authorId);

    hasUnreadCaseReview = true;
    notifyListeners();
  }

  // 특정 유저에게 훈련 리포트 생성 및 피드백 알림 전송 🔴
  Future<void> triggerReportNotification(String targetUserId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    _traineeReportTimes[targetUserId] = now;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_report_completed_time_$targetUserId', now);

    notifyListeners();
  }

  // 관리자가 작성한 피드백 코멘트를 리포트에 반영하고, 실제로 내용에 변경이 있을 때만 안읽음(NEW 🔴) 전환 트리거
  void setAdminReportComment(String reportId, String comment, String targetUserId) {
    final index = practiceReports.indexWhere((r) => r.id == reportId);
    if (index != -1) {
      final oldComment = practiceReports[index].adminComment ?? '';
      final newCommentTrimmed = comment.trim();

      // 기존 코멘트 내용과 완전 일치하여 변경 사항이 없는 경우 알림 스킵!
      if (oldComment.trim() == newCommentTrimmed) {
        return;
      }

      practiceReports[index].adminComment = newCommentTrimmed;
    }

    triggerReportNotification(targetUserId);
    notifyListeners();
  }

  Future<void> loadData({String? baseUrl}) async {
    if (isLoaded) return;

    // 1. Load Scenarios from Local Asset
    final scenariosString = await rootBundle.loadString('assets/data/scenarios.json');
    final List<dynamic> scenariosJson = json.decode(scenariosString);
    scenarioStore = scenariosJson.map((json) => RoleplayScenario.fromJson(json)).toList();

    // 2. Load References
    final referencesString = await rootBundle.loadString('assets/data/references.json');
    final List<dynamic> referencesJson = json.decode(referencesString);
    references = referencesJson.map((json) => OfficialReference.fromJson(json)).toList();

    // 3. Load Rules
    final rulesString = await rootBundle.loadString('assets/data/rules.json');
    final Map<String, dynamic> rulesJson = json.decode(rulesString);
    rulesByIndustry = rulesJson.map((key, value) => MapEntry(key, List<String>.from(value)));

    // 4. Field Cases (기본 샘플 제거, 빈 리스트로 시작)
    fieldCaseStore = [];

    // 5. 로컬 저장소에 저장된 변경된 시나리오 로드하여 기본 에셋 오버라이드
    await _loadScenariosFromLocalPrefs();

    isLoaded = true;

    // 6. Fetch Latest Scenarios from Backend if baseUrl is available
    if (baseUrl != null && baseUrl.isNotEmpty) {
      await _fetchScenariosInternal(baseUrl);
    }

    updateRecommendedScenario(forceReshuffle: false);
    notifyListeners();
  }

  // 내부 시나리오 동기화 로직 (중복 추천 갱신 방지)
  Future<void> _fetchScenariosInternal(String baseUrl) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/scenarios'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(utf8.decode(response.bodyBytes));
        final serverScenarios = jsonList.map((j) => RoleplayScenario.fromJson(j)).toList();
        
        // 💡 버그 픽스: Map 병합에서 List 기반 완전 동기화로 개편
        // 백엔드 DB를 최신 Source of Truth로 삼아 덮어쓰되, 
        // 아직 서버에 업로드/공개되지 않은 로컬 오프라인 초안(draft)만 보존합니다.
        final List<RoleplayScenario> syncedScenarios = List.from(serverScenarios);
        for (final local in scenarioStore) {
          final exists = serverScenarios.any((s) => s.id == local.id);
          if (!exists && !local.isPublished) {
            syncedScenarios.add(local);
          }
        }
        scenarioStore = syncedScenarios;
        _saveScenariosToLocalPrefs(); // 서버 최신 수신본을 로컬 저장소에도 영구 동기화
      }
    } catch (e) {
      debugPrint('백엔드 시나리오 동기화 실패 (로컬 유지): $e');
    }
  }

  // 백엔드에서 시나리오 목록 최신화 수신
  Future<void> fetchScenariosFromBackend(String baseUrl) async {
    await _fetchScenariosInternal(baseUrl);
    updateRecommendedScenario(forceReshuffle: false);
    notifyListeners();
  }

  void addFieldCase(FieldCase fieldCase, {String? token, String? baseUrl}) {
    fieldCaseStore.insert(0, fieldCase);
    // 관리자 유저들에게 현장 사례 검토 알림 발동 🔴
    triggerCaseReviewNotification(fieldCase.authorId);
    notifyListeners();
  }

  void deleteFieldCase(String caseId, {String? token, String? baseUrl}) {
    fieldCaseStore.removeWhere((c) => c.id == caseId);
    notifyListeners();
  }

  void markCaseAsConverted(String caseId, {String? token, String? baseUrl}) {
    final index = fieldCaseStore.indexWhere((c) => c.id == caseId);
    if (index != -1) {
      fieldCaseStore[index].status = FieldCaseStatus.approved;
      fieldCaseStore[index].isConvertedToScenario = true;
      notifyListeners();
    }
  }

  // 유저 전환/로그아웃 시 이전 유저의 훈련 리포트 상태 및 알림 초기화
  void clearUserData() {
    practiceReports.clear();
    readScenarioIds.clear();
    readReportIds.clear();
    _scenarioModTimes.clear();
    _scenarioReadTimes.clear();
    _traineeReportTimes.clear();
    _adminUserCheckTimes.clear();
    currentUserId = null;
    hasUnreadCaseReview = false;
    currentRecommendedScenario = null;
    updateRecommendedScenario(forceReshuffle: false);
    notifyListeners();
  }

  // 내부 훈련 리포트 동기화 로직 (안전한 시간/ID 기반 병합)
  Future<void> _fetchReportsInternal(String token, String baseUrl) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_unique_id') ?? '';

      final response = await http.get(
        Uri.parse('$baseUrl/users/me/reports?device_id=$deviceId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> reportsJson = json.decode(utf8.decode(response.bodyBytes));
        final backendReports = reportsJson.map((j) => PracticeReport.fromJson(j)).toList();

        // 💡 버그 픽스: Map Key 충돌로 인한 중복/덮어쓰기 오류 방지를 위해 List 기반 완전 교체 로직 적용
        final List<PracticeReport> syncedReports = List.from(backendReports);

        for (final local in practiceReports) {
          // 백엔드 리포트와 동일한 항목이 있는지 검사 (DB ID가 같거나, 시나리오ID+수행시각이 완벽히 일치하는 경우)
          final existsInBackend = backendReports.any((b) => 
              b.id == local.id || 
              (b.scenarioId.trim() == local.scenarioId.trim() && 
               b.dateTime.millisecondsSinceEpoch == local.dateTime.millisecondsSinceEpoch)
          );
          
          // 백엔드에 아직 저장되지 않은 로컬 오프라인 전용 생성 리포트만 추가 보존
          if (!existsInBackend) {
              syncedReports.add(local);
          }
        }

        practiceReports = syncedReports;
        practiceReports.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      } else if (response.statusCode == 401 && currentUserId != null) {
        ServerConnectionHandler.handleDisconnection('인증 세션이 만료되었습니다.\n다시 로그인해 주세요.');
      } else if (response.statusCode == 409 && currentUserId != null) {
        ServerConnectionHandler.handleDisconnection('다른 기기에서 동일한 유저로 로그인이 감지되었습니다.\n현재 기기에서는 로그아웃되며, 다시 이용하시려면 로그인해 주세요.');
      }
    } catch (e) {
      debugPrint('백엔드 훈련 리포트 동기화 실패: $e');
      if (currentUserId != null) {
        ServerConnectionHandler.handleDisconnection();
      }
    }
  }

  // 백엔드에서 현재 로그인한 유저의 과거 훈련 이력 목록 수신하여 동기화
  Future<void> fetchReportsFromBackend(String? token, String baseUrl) async {
    if (token == null || token.isEmpty) {
      return;
    }
    await _fetchReportsInternal(token, baseUrl);
    updateRecommendedScenario(forceReshuffle: false);
    notifyListeners();
  }

  // 당겨서 새로고침 알고리즘 (새로고침 시 단 1회만 forceReshuffle = true 로 변경 및 단일 UI 리빌드 보장)
  Future<void> refreshData({String? token, String? baseUrl}) async {
    final minDelay = Future.delayed(const Duration(milliseconds: 600));

    // 1. 비동기 패치 (중간 상태 변경 및 중간 셔플 제거)
    if (baseUrl != null && baseUrl.isNotEmpty) {
      await _fetchScenariosInternal(baseUrl);
    }
    if (token != null && token.isNotEmpty && baseUrl != null && baseUrl.isNotEmpty) {
      await _fetchReportsInternal(token, baseUrl);
    }

    // 2. 단 1회만 우선순위 기반 추천 상황극 재선출 (동급 후보군 로테이션 적용)
    updateRecommendedScenario(forceReshuffle: true);

    // 3. 최소 애니메이션 딜레이 보장 후 단 1회만 notifyListeners 호출
    await minDelay;
    notifyListeners();
  }

  // 🎯 스마트 맞춤 추천 상황극 우선순위 산출 알고리즘 (무작위 셔플 제거, 우선순위 체계 적용)
  void updateRecommendedScenario({bool forceReshuffle = false}) {
    final published = scenarioStore.where((s) => s.isPublished).toList();
    if (published.isEmpty) {
      currentRecommendedScenario = null;
      return;
    }

    // 🌟 우선순위 1: 새로 추가/공개되었으나 유저가 아직 확인하지 않은 신규 상황극 (NEW 🔴)
    final newScenarios = published.where((s) => isScenarioNew(s.id)).toList();
    if (newScenarios.isNotEmpty) {
      currentRecommendedScenario = _selectFromCandidates(newScenarios, forceReshuffle);
      return;
    }

    // 🌟 우선순위 2: 아직 한 번도 훈련해 보지 않은 연습 미완료 상황극
    final practicedIds = practiceReports.map((r) => r.scenarioId.trim()).toSet();
    final unpracticed = published.where((s) => !practicedIds.contains(s.id.trim())).toList();
    if (unpracticed.isNotEmpty) {
      currentRecommendedScenario = _selectFromCandidates(unpracticed, forceReshuffle);
      return;
    }

    // 🌟 우선순위 3: 최근 연습 점수가 낮은(80점 미만) 보완 필요 상황극 (낮은 점수순 후보군)
    final lowReports = lowScoreLatestReports;
    if (lowReports.isNotEmpty) {
      final lowScoreScenarioIds = lowReports.map((r) => r.scenarioId.trim()).toSet();
      final lowScenarios = published.where((s) => lowScoreScenarioIds.contains(s.id.trim())).toList();
      if (lowScenarios.isNotEmpty) {
        currentRecommendedScenario = _selectFromCandidates(lowScenarios, forceReshuffle);
        return;
      }
    }

    // 🌟 우선순위 4: 모든 상황극을 완수한 경우 전체 시나리오 중 로테이션
    currentRecommendedScenario = _selectFromCandidates(published, forceReshuffle);
  }

  // 동일한 우선순위 후보군 안에서 로테이션하여 다양한 상황극을 선택하는 헬퍼 함수
  RoleplayScenario _selectFromCandidates(List<RoleplayScenario> candidates, bool forceReshuffle) {
    if (candidates.isEmpty) return candidates.first;
    if (candidates.length == 1) return candidates.first;

    final currentIndex = currentRecommendedScenario != null
        ? candidates.indexWhere((s) => s.id == currentRecommendedScenario!.id)
        : -1;

    // 새로고침이 아니고 이미 현 추천 시나리오가 동일 후보군에 포함된 경우 기존 선택 유지 (화면 흔들림 방지)
    if (!forceReshuffle && currentIndex != -1) {
      return candidates[currentIndex];
    }

    // 새로고침 시 동일한 우선순위 후보군 내에서 순차적으로 로테이션 선택하여 다양한 상황극 노출
    final nextIndex = currentIndex == -1 ? 0 : (currentIndex + 1) % candidates.length;
    return candidates[nextIndex];
  }

  void addReport(PracticeReport report, {String? token, String? baseUrl, String? targetUserId}) {
    practiceReports.add(report);
    
    // 특정 수습생 유저에게 훈련 리포트 안읽음(NEW 🔴) 상태 트리거
    final uid = targetUserId ?? currentUserId;
    if (uid != null && uid.isNotEmpty) {
      invalidateReadReportForUser(report.id, uid);
    }

    updateRecommendedScenario(forceReshuffle: true);
    notifyListeners();

    if (token != null && token.isNotEmpty && baseUrl != null && baseUrl.isNotEmpty) {
      _saveReportToBackend(report, token, baseUrl);
    }
  }

  Future<void> _saveReportToBackend(PracticeReport report, String token, String baseUrl) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_unique_id') ?? '';

      final response = await http.post(
        Uri.parse('$baseUrl/users/me/reports?device_id=$deviceId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(report.toBackendJson()),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final createdReport = PracticeReport.fromJson(data);

        // 로컬 리포트 객체를 서버에서 정식 발급된 DB ID 객체로 교체
        final index = practiceReports.indexWhere((r) => r.id == report.id || (r.scenarioId.trim() == report.scenarioId.trim() && r.dateTime.millisecondsSinceEpoch == report.dateTime.millisecondsSinceEpoch));
        if (index != -1) {
          practiceReports[index] = createdReport;
        } else {
          practiceReports.add(createdReport);
        }
        notifyListeners();
        debugPrint('백엔드 DB에 훈련 리포트 정식 저장 성공! (DB ID: ${createdReport.id})');
      } else if (response.statusCode == 401 && currentUserId != null) {
        ServerConnectionHandler.handleDisconnection('인증 세션이 만료되었습니다.\n다시 로그인해 주세요.');
      }
    } catch (e) {
      debugPrint('백엔드 훈련 리포트 저장 실패: $e');
      if (currentUserId != null) {
        ServerConnectionHandler.handleDisconnection();
      }
    }
  }

  Map<String, List<PracticeReport>> get groupedReports {
    final Map<String, List<PracticeReport>> grouped = {};
    for (final report in practiceReports) {
      final sId = report.scenarioId.trim();
      if (sId.isNotEmpty) {
        grouped.putIfAbsent(sId, () => []).add(report);
      }
    }
    for (final list in grouped.values) {
      list.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    }
    return grouped;
  }

  List<PracticeReport> get lowScoreLatestReports {
    final grouped = groupedReports;
    final List<PracticeReport> lowReports = [];
    for (final reports in grouped.values) {
      if (reports.isNotEmpty) {
        final latest = reports.first;
        if (latest.score < 80) {
          lowReports.add(latest);
        }
      }
    }
    lowReports.sort((a, b) => a.score.compareTo(b.score));
    return lowReports;
  }

  List<PracticeReport> getReportsForScenario(String scenarioId) {
    final targetId = scenarioId.trim();
    final list = practiceReports.where((r) => r.scenarioId.trim() == targetId).toList();
    list.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return list;
  }

  // 타 유저들의 개별 읽음 세트에서 시나리오 ID 제외 처리하여 안읽음(NEW)으로 복원
  void invalidateReadScenarioForOthers(String scenarioId, String creatorId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    _scenarioModTimes[scenarioId] = now;

    // 1. 현재 로그인된 유저가 제작한 본인이 아닌 경우 안읽음(NEW 🔴)으로 전환
    if (currentUserId != null && currentUserId != creatorId) {
      readScenarioIds.remove(scenarioId);
    }
    
    // 2. 저장소의 시나리오 수정 타임스탬프 갱신
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('scenario_mod_time_$scenarioId', now);
    await prefs.setInt('last_scenario_published_time', now);
    await prefs.setString('last_scenario_publisher_id', creatorId);
  }

  // 시나리오 내용이 실제로 수정되었는지 비교하는 헬퍼 함수
  bool _hasScenarioContentChanged(RoleplayScenario oldScenario, RoleplayScenario newScenario) {
    if (oldScenario.title.trim() != newScenario.title.trim()) return true;
    if (oldScenario.industry.trim() != newScenario.industry.trim()) return true;
    if (oldScenario.situation.trim() != newScenario.situation.trim()) return true;
    if (oldScenario.expectedActions.trim() != newScenario.expectedActions.trim()) return true;
    if (oldScenario.linkedRules.trim() != newScenario.linkedRules.trim()) return true;
    if (oldScenario.isPublished != newScenario.isPublished) return true;

    if (oldScenario.referenceCodes.length != newScenario.referenceCodes.length) return true;
    for (int i = 0; i < oldScenario.referenceCodes.length; i++) {
      if (oldScenario.referenceCodes[i] != newScenario.referenceCodes[i]) return true;
    }

    return false; // 실제 변경 사항 없음!
  }

  // 신규 시나리오 저장 (로컬 + 백엔드 DB)
  void addScenario(RoleplayScenario scenario, {String? token, String? baseUrl, String? creatorId}) {
    scenarioStore.add(scenario);
    if (scenario.isPublished) {
      if (creatorId != null && creatorId == currentUserId) {
        markScenarioAsRead(scenario.id);
      }
      invalidateReadScenarioForOthers(scenario.id, creatorId ?? 'admin');
    }
    _saveScenariosToLocalPrefs(); // 로컬 저장소에도 영구 보관
    updateRecommendedScenario(forceReshuffle: true);
    notifyListeners();

    if (token != null && token.isNotEmpty && baseUrl != null && baseUrl.isNotEmpty) {
      _saveScenarioToBackend(scenario, token, baseUrl);
    }
  }

  Future<void> _saveScenarioToBackend(RoleplayScenario scenario, String token, String baseUrl) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/scenarios'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(scenario.toJson()),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 201) {
        debugPrint('백엔드 DB에 시나리오 저장 성공!');
      } else if (response.statusCode == 401 && currentUserId != null) {
        ServerConnectionHandler.handleDisconnection('인증 세션이 만료되었습니다.\n다시 로그인해 주세요.');
      }
    } catch (e) {
      debugPrint('백엔드 시나리오 저장 실패: $e');
      if (currentUserId != null) {
        ServerConnectionHandler.handleDisconnection();
      }
    }
  }

  // 시나리오 삭제 (로컬 + 백엔드 DB)
  void removeScenario(String id, {String? token, String? baseUrl}) {
    scenarioStore.removeWhere((s) => s.id == id);
    _saveScenariosToLocalPrefs(); // 로컬 저장소 업데이트
    updateRecommendedScenario(forceReshuffle: true);
    notifyListeners();

    if (token != null && token.isNotEmpty && baseUrl != null && baseUrl.isNotEmpty) {
      _deleteScenarioOnBackend(id, token, baseUrl);
    }
  }

  Future<void> _deleteScenarioOnBackend(String id, String token, String baseUrl) async {
    try {
      await http.delete(
        Uri.parse('$baseUrl/scenarios/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('백엔드 시나리오 삭제 실패: $e');
      if (currentUserId != null) {
        ServerConnectionHandler.handleDisconnection();
      }
    }
  }

  void toggleScenarioPublished(String id, {String? token, String? baseUrl, String? creatorId}) {
    final index = scenarioStore.indexWhere((s) => s.id == id);
    if (index != -1) {
      final wasPublished = scenarioStore[index].isPublished;
      scenarioStore[index].isPublished = !wasPublished;
      
      // 비공개에서 공개로 바뀐 경우에만 알림 발동 및 안읽음 상태 복원
      if (!wasPublished && scenarioStore[index].isPublished) {
        if (creatorId != null && creatorId == currentUserId) {
          markScenarioAsRead(scenarioStore[index].id);
        }
        invalidateReadScenarioForOthers(scenarioStore[index].id, creatorId ?? 'admin');
      }

      _saveScenariosToLocalPrefs(); // 로컬 저장소 업데이트
      updateRecommendedScenario(forceReshuffle: true);
      notifyListeners();

      if (token != null && token.isNotEmpty && baseUrl != null && baseUrl.isNotEmpty) {
        _updateScenarioOnBackend(scenarioStore[index], token, baseUrl);
      }
    }
  }

  // 시나리오 수정 (실제 내용 수정 시에만 알림 발동 및 안읽음 복원, 내용 미수정 시 기존 알림 상태 보존)
  void updateScenario(RoleplayScenario scenario, {String? token, String? baseUrl, String? creatorId}) {
    final index = scenarioStore.indexWhere((s) => s.id == scenario.id);
    if (index != -1) {
      final oldScenario = scenarioStore[index];
      final contentChanged = _hasScenarioContentChanged(oldScenario, scenario);

      scenarioStore[index] = scenario;

      // 실제 내용이 변경되었고 공개 상태인 경우에만 수습생 알림 및 안읽음(NEW 🔴)으로 복원!
      if (contentChanged && scenario.isPublished) {
        if (creatorId != null && creatorId == currentUserId) {
          markScenarioAsRead(scenario.id);
        }
        invalidateReadScenarioForOthers(scenario.id, creatorId ?? 'admin');
      }

      _saveScenariosToLocalPrefs(); // 로컬 저장소 업데이트
      updateRecommendedScenario(forceReshuffle: contentChanged);
      notifyListeners();

      if (token != null && token.isNotEmpty && baseUrl != null && baseUrl.isNotEmpty) {
        _updateScenarioOnBackend(scenario, token, baseUrl);
      }
    }
  }

  Future<void> _updateScenarioOnBackend(RoleplayScenario scenario, String token, String baseUrl) async {
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
      if (currentUserId != null) {
        ServerConnectionHandler.handleDisconnection();
      }
    }
  }
}
