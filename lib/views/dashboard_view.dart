import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/roleplay_scenario.dart';
import '../models/user_model.dart';
import '../models/field_case.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../utils/ui_helpers.dart';
import 'admin_user_detail_view.dart';
import 'case_form_view.dart';
import 'login_view.dart';
import 'report_detail_view.dart';
import 'rules_view.dart';
import 'store_rules_view.dart';
import 'scenario_form_view.dart';
import 'session_setup_view.dart';
import 'rag_search_view.dart';

class Dashboard extends ConsumerStatefulWidget {
  const Dashboard({super.key});
  @override
  ConsumerState<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends ConsumerState<Dashboard> {
  int tab = 0;
  int _previousTab = 0; // 방향성 탭 전환 애니메이션용 이전 탭 인덱스 추적
  int adminSubTab = 0; // 0: 시나리오 관리, 1: 사례 검토 및 변환, 2: 유저 회원 관리
  String selectedIndustry = '전체';
  String selectedReportIndustry = '전체';

  List<UserModel> adminUsers = [];
  bool isLoadingAdminUsers = false;
  bool _isRefreshing = false; // 상호작용 제어용 플래그
  int _refreshKeyCounter = 0; // 새로고침 시 화면 리프레시 애니메이션 트리거 카운터

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // 앱 진입 시 1. 시나리오 데이터 로드 ➔ 2. 유저별 독립 알림 동기화 ➔ 3. 백엔드 리포트 패치
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final dataService = ref.read(dataServiceProvider);
      final authService = ref.read(authServiceProvider);

      await dataService.loadData(baseUrl: authService.baseUrl);

      if (authService.currentUser != null) {
        authService.startHeartbeatCheck(); // 💡 1초 경량 하트비트 시동 (새 기기 로그인 시 1초 만에 알림 수신 보장)
        await dataService.syncUserNotifications(
          authService.currentUser!.id,
          isAdmin: authService.isAdmin,
        );
      }

      await dataService.fetchReportsFromBackend(
        authService.accessToken,
        authService.baseUrl,
      );

      if (authService.isAdmin) {
        _loadAdminUsers();
      }
    });
  }

  Future<void> _loadAdminUsers() async {
    final authService = ref.read(authServiceProvider);
    if (!authService.isAdmin) return;

    final users = await authService.fetchAdminUsers();
    if (mounted) {
      setState(() {
        adminUsers = users;
        isLoadingAdminUsers = false;
      });
    }
  }

  void open(Widget page) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => page),
  ).then((_) => setState(() {}));

  void startPractice(RoleplayScenario scenario) => open(SessionSetupView(scenario: scenario));

  void selectTab(int index) {
    if (_isRefreshing) return; // 새로고침 진행 중에는 탭 이동 차단
    if (tab == index) return;

    final dataService = ref.read(dataServiceProvider);

    if (index == 0) {
      // 💡 수동 홈 탭 이동 시에만 추천 상황극 신규 교체
      dataService.updateRecommendedScenario(forceReshuffle: true);
    }

    setState(() {
      _previousTab = tab;
      tab = index;
      _refreshKeyCounter++; // 💡 탭 전환 시마다 고유 세션 키를 생성하여 새 탭의 모든 위젯 애니메이션 재발동
    });

    if (index == 4) {
      // 관리자 탭 클릭 시
      _loadAdminUsers();
      if (adminSubTab == 1) {
        dataService.clearCaseReviewNotification();
      }
    }
  }

  Future<void> _performLogout() async {
    if (_isRefreshing) return;

    final dataService = ref.read(dataServiceProvider);
    final authService = ref.read(authServiceProvider);

    // 1. 서버 상의 기기 세션 해제 및 토큰 삭제 비동기 수행 완료까지 대기
    await authService.logout(dataService);

    if (!mounted) return;

    // 2. 토큰 및 세션 삭제가 완전히 끝난 후 LoginView(skipAutoLogin: true)로 이동하여 1번에 즉시 로그아웃 처리
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginView(skipAutoLogin: true)),
      (route) => false,
    );
  }

  void _logout() async {
    if (_isRefreshing) return;

    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xff146b59)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      await _performLogout();
    }
  }

  // 🔴 통일된 빨간 닷 알림뱃지 아이콘 위젯 (하단 네비게이션 바 & 상단 서브 탭 공통)
  Widget _buildNavIcon(IconData iconData, bool showRedDot) {
    if (!showRedDot) return Icon(iconData, size: 20);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(iconData, size: 20),
        const Positioned(
          right: -2,
          top: -2,
          child: CircleAvatar(
            radius: 4.5,
            backgroundColor: Colors.red,
          ),
        ),
      ],
    );
  }

  // 🔴 상단 관리자 서브 탭 바 (하단 네비게이션과 동일한 디자인 톤 & 매끄러운 색상 전환)
  Widget _buildAdminSubTabBar(DataService dataService) {
    final bool hasUnreadUserReports = dataService.hasUnreadAdminUserReports(adminUsers);

    final tabs = [
      {'index': 0, 'label': '시나리오', 'icon': Icons.edit_note, 'badge': false},
      {'index': 1, 'label': '사례 검토/변환', 'icon': Icons.rate_review_outlined, 'badge': dataService.hasUnreadCaseReview},
      {'index': 2, 'label': '유저 관리', 'icon': Icons.people_alt_outlined, 'badge': hasUnreadUserReports},
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xffe8eee9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: tabs.map((t) {
          final int idx = t['index'] as int;
          final String label = t['label'] as String;
          final IconData icon = t['icon'] as IconData;
          final bool showBadge = t['badge'] as bool;
          final bool isSelected = adminSubTab == idx;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (_isRefreshing) return;
                setState(() {
                  adminSubTab = idx;
                });
                if (idx == 1) {
                  dataService.clearCaseReviewNotification();
                } else if (idx == 2) {
                  _loadAdminUsers();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : const Color(0xffe8eee9),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isSelected ? 0.05 : 0.0),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildNavIcon(icon, showBadge),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? const Color(0xff146b59) : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _performSearch(String query) {
    if (query.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    _searchController.clear();

    final authService = ref.read(authServiceProvider);
    // 🌟 신규 검색: 이전 기록을 섞지 않고 완전히 새 화면으로 시작
    ref.read(ragChatViewModelProvider).startNewSearch(
      query, 
      authService.baseUrl, 
      authService.accessToken,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const RagChatBottomSheet(),
    );
  }

  Widget _buildSearchFABWrapper(bool showSearchBar) {
    return AnimatedSlide(
      offset: showSearchBar ? Offset.zero : const Offset(0.0, 2.5), // 💡 위로 나타남(0.0) / 아래로 슬라이드 숨김(2.5)
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOutCubic,
      child: AnimatedOpacity(
        opacity: showSearchBar ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 250),
        child: IgnorePointer(
          ignoring: !showSearchBar, // 숨김 상태 시 터치 이벤트 차단
          child: _buildSearchFAB(),
        ),
      ),
    );
  }

  Widget _buildSearchFAB() {
    final ragViewModel = ref.watch(ragChatViewModelProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 📋 직전 검색 결과 확인 버튼 (이전 검색 기록이 있는 경우에만 표시)
        if (ragViewModel.hasPreviousResult) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 6.0, right: 4.0),
            child: ActionChip(
              avatar: const Icon(Icons.history_rounded, size: 16, color: Color(0xff146b59)),
              label: const Text('직전 검색 결과 보기', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xff146b59))),
              backgroundColor: Colors.white,
              side: BorderSide(color: const Color(0xff146b59).withValues(alpha: 0.35), width: 1.2),
              elevation: 3,
              shadowColor: Colors.black26,
              onPressed: () {
                ragViewModel.restorePreviousSearch();
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (ctx) => const RagChatBottomSheet(),
                );
              },
            ),
          ),
        ],

        // 메인 상시 1줄 검색 입력창
        Container(
          width: MediaQuery.of(context).size.width - 32, // 화면 가로폭에 맞춘 세련된 카드 형태
          margin: const EdgeInsets.only(bottom: 4),
          constraints: const BoxConstraints(
            minHeight: 46, // 폰트 배율이 커도 1줄 상태로 슬림하게 유지
            maxHeight: 110, // 사용자가 긴 글 입력 시 자동 세로 확장
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white, // 깔끔한 화이트 메인 카드 배경
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xff146b59).withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 2, right: 6),
                child: Icon(Icons.auto_awesome_rounded, color: Color(0xff146b59), size: 20),
              ),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  minLines: 1, // 한 줄로 깔끔하게 시작
                  maxLines: null, // 내용 초과 시 유연하게 자동 세로 확장
                  keyboardType: TextInputType.multiline,
                  style: const TextStyle(color: Colors.black87, fontSize: 13.5, height: 1.3),
                  cursorColor: const Color(0xff146b59),
                  decoration: InputDecoration(
                    hintText: '매장 운영규칙 질문하기...', // 화면 배율이 커도 1줄을 유지하는 간결한 힌트 문구
                    hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                  ),
                  onChanged: (val) {
                    // 엔터키 입력 시 즉시 전송
                    if (val.endsWith('\n')) {
                      _searchController.text = val.substring(0, val.length - 1);
                      _performSearch(_searchController.text);
                    }
                  },
                ),
              ),
              const SizedBox(width: 4),
              Material(
                color: const Color(0xff146b59),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _performSearch(_searchController.text),
                  child: const Padding(
                    padding: EdgeInsets.all(6.0),
                    child: Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final dataService = ref.watch(dataServiceProvider);
    final authService = ref.watch(authServiceProvider);
    final bool isAdmin = authService.isAdmin;

    // 일반 유저는 관리자 탭(4번) 접근 불가 -> 탭 범위 자동 보정
    if (!isAdmin && tab >= 4) {
      tab = 0;
    }

    if (!dataService.isLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final published = dataService.scenarioStore.where((s) => s.isPublished).toList();
    final visibleScenarios = selectedIndustry == '전체'
        ? published
        : published.where((s) => s.industry == selectedIndustry).toList();
    final drafts = dataService.scenarioStore.where((s) => !s.isPublished).toList();
    final recScenario = dataService.currentRecommendedScenario;

    // 📂 유저용 카테고리/업종별 그룹화 시나리오 Map
    final Map<String, List<RoleplayScenario>> groupedVisibleScenarios = {};
    for (final s in visibleScenarios) {
      groupedVisibleScenarios.putIfAbsent(s.industry, () => []).add(s);
    }

    // 📂 관리자용 카테고리/업종별 그룹화 전체 시나리오 Map
    final Map<String, List<RoleplayScenario>> groupedAdminScenarios = {};
    for (final s in dataService.scenarioStore) {
      groupedAdminScenarios.putIfAbsent(s.industry, () => []).add(s);
    }
    
    final allPages = <List<Widget>>[
      // 0번 탭: 홈
      [
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.waving_hand_outlined, size: 30, color: Theme.of(context).colorScheme.onPrimaryContainer),
                const SizedBox(height: 14),
                Text('첫 근무, 차근차근 연습해요', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Theme.of(context).colorScheme.onPrimaryContainer)),
                const SizedBox(height: 8),
                Text('매장에서 만날 수 있는 상황을 골라 응대 순서를 익혀보세요.', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onPrimaryContainer)),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () => selectTab(1),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('상황 둘러보기'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // 낮은 점수 / 보완 필요 상황극 영역
        _buildLowScoreSection(dataService),
        const SizedBox(height: 16),
        Text('맞춤형 추천 상황', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        if (recScenario != null)
          panel(
            '${recScenario.title}',
            '${recScenario.industry} | ${recScenario.situation}',
            Icons.auto_awesome_outlined,
            () => startPractice(recScenario),
          )
        else
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('추천 가능한 상황극이 없습니다.'),
            ),
          ),
        const SizedBox(height: 12),
        panel('교육 리포트', '지난 연습 결과와 보완할 항목을 확인하세요.', Icons.insights, () => selectTab(2)),
        panel('매장 운영규칙', '매장 규칙과 현장 사례를 확인하세요.', Icons.storefront, () => selectTab(3)),
      ],

      // 1번 탭: 상황극 목록 (카테고리/업종별 그룹화 표시)
      [
        Text('어떤 상황을 연습할까요?', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        const Text('업종을 선택하거나 아래 카테고리별 상황극을 살펴보세요.'),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final industry in ['전체', '카페', '편의점', '식당'])
              ChoiceChip(
                label: Text(industry),
                selected: selectedIndustry == industry,
                onSelected: (_) => setState(() => selectedIndustry = industry),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (visibleScenarios.isEmpty)
          const Card(child: ListTile(leading: Icon(Icons.search_off), title: Text('표시할 상황이 없습니다.'), subtitle: Text('다른 업종을 선택해 보세요.'))),

        for (final category in groupedVisibleScenarios.keys) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(_industryIcon(category), size: 20, color: const Color(0xff146b59)),
              const SizedBox(width: 8),
              Text(
                '$category (${groupedVisibleScenarios[category]!.length}개)',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final s in groupedVisibleScenarios[category]!) ...[
            Builder(
              builder: (context) {
                final isNew = dataService.isScenarioNew(s.id);
                return Card(
                  child: ListTile(
                    minVerticalPadding: 16,
                    leading: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(child: Icon(_industryIcon(s.industry))),
                        if (isNew)
                          const Positioned(
                            right: -2,
                            top: -2,
                            child: CircleAvatar(
                              radius: 4.5,
                              backgroundColor: Colors.red,
                            ),
                          ),
                      ],
                    ),
                    title: Text(s.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(s.situation, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      dataService.markScenarioAsRead(s.id);
                      startPractice(s);
                    },
                  ),
                );
              },
            ),
          ],
        ],
      ],

      // 2번 탭: 교육 리포트 대시보드
      _buildReportDashboard(dataService),

      // 3번 탭: 매장 운영규칙 및 법령
      [
        panel('매장 운영규칙', '업종별 자체 매장 규칙과 매뉴얼을 확인하세요.', Icons.storefront_outlined, () => open(const StoreRulesView())),
        panel('관련 법령 및 지침', '상황극에 연결될 수 있는 관련 법령 정보를 확인하세요.', Icons.gavel_outlined, () => open(const RulesPage())),
        panel('현장 사례 등록', '실제 매장에서 일어난 응대 사례를 등록합니다.', Icons.note_add, () => open(const CaseForm())),
      ],

      // 4번 탭: 관리자 전용 대시보드 (서브탭 구분: 0:시나리오 관리 / 1:사례 검토 및 변환 / 2:유저 관리)
      [
        _buildAdminSubTabBar(dataService),
        const SizedBox(height: 18),

        if (adminSubTab == 0) ...[
          // 서브 탭 0: 카테고리별 시나리오 수정 및 신규 등록 관리
          const Text('상황극 시나리오를 새로 만들어 등록하거나 카테고리별 기존 시나리오를 수정/삭제합니다.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => open(const ScenarioForm()),
            icon: const Icon(Icons.add),
            label: const Text('신규 시나리오 직접 만들기'),
          ),
          const SizedBox(height: 16),
          Text('등록된 시나리오 목록 (${dataService.scenarioStore.length}개)', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),

          for (final category in groupedAdminScenarios.keys) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(_industryIcon(category), size: 20, color: const Color(0xff146b59)),
                const SizedBox(width: 8),
                Text(
                  '$category 카테고리 (${groupedAdminScenarios[category]!.length}개)',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (final s in groupedAdminScenarios[category]!)
              _adminScenarioCard(s, dataService, authService),
          ],

          if (drafts.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('💡 초안 시나리오는 관리자 목록에만 표시되며 일반 연습 목록에는 나타나지 않습니다.'),
            ),
        ] else if (adminSubTab == 1) ...[
          // 서브 탭 1: 제출된 현장 사례 검토 및 시나리오 변환 (삭제 & 시나리오 추가만 지원)
          _buildAdminCaseReviewSection(dataService),
        ] else ...[
          // 서브 탭 2: 유저 회원 및 진행 데이터 상세 관리
          _buildUserManagementSection(authService),
        ],
      ],
    ];

    final pageTitles = isAdmin
        ? ['첫 근무 노트', '상황극', '교육 리포트', '운영규칙', '관리자']
        : ['첫 근무 노트', '상황극', '교육 리포트', '운영규칙'];

    final activePages = isAdmin ? allPages : allPages.sublist(0, 4);

    final bool isMovingRight = tab > _previousTab;
    final bool isMovingLeft = tab < _previousTab;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (tab != 0) {
          // 홈 탭이 아닌 다른 탭에 있을 경우 홈 탭(0번)으로 이동
          dataService.updateRecommendedScenario(forceReshuffle: true);
          setState(() {
            _previousTab = tab;
            tab = 0;
            _refreshKeyCounter++; // 💡 홈 탭 복귀 시 고유 세션 키 생성으로 위젯 애니메이션 재발동
          });
        } else {
          // 홈 탭일 경우: 로그인 상태에 따라 안내 팝업 및 옵션 다르게 표출
          final isLoggedIn = authService.isLoggedIn;

          if (isLoggedIn) {
            // 💡 로그인 상태일 때: [로그아웃], [앱 종료], [취소] 다이얼로그
            final action = await showDialog<String>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.exit_to_app_rounded, color: Color(0xff146b59)),
                    SizedBox(width: 8),
                    Text('종료 및 로그아웃', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
                content: Text(
                  '[${authService.currentUser?.name ?? "사용자"}] 님, 로그아웃 하시겠습니까 아니면 앱을 종료하시겠습니까?',
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, 'cancel'),
                    child: const Text('취소'),
                  ),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, 'logout'),
                    child: const Text('로그아웃'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xff146b59)),
                    onPressed: () => Navigator.pop(ctx, 'exit'),
                    child: const Text('앱 종료'),
                  ),
                ],
              ),
            );

            if (action == 'logout' && mounted) {
              await _performLogout();
            } else if (action == 'exit' && mounted) {
              SystemNavigator.pop(); // 앱 종료
            }
          } else {
            // 💡 미로그인/로그인 전 상태일 때: [앱 종료], [취소] 옵션만 표시
            final shouldExit = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('앱 종료'),
                content: const Text('앱을 종료하시겠습니까?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('취소'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xff146b59)),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('종료'),
                  ),
                ],
              ),
            );

            if (shouldExit == true && mounted) {
              SystemNavigator.pop(); // 앱 종료
            }
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(pageTitles[tab]),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Center(
                child: Chip(
                  avatar: Icon(isAdmin ? Icons.admin_panel_settings : Icons.person, size: 16),
                  label: Text(
                    '${authService.currentUser?.name ?? "사용자"} (${isAdmin ? "관리자" : "일반"})',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: '로그아웃',
              icon: const Icon(Icons.logout_rounded),
              onPressed: _logout,
            ),
          ],
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
            return Stack(
              alignment: Alignment.topCenter,
              children: <Widget>[
                ...previousChildren,
                if (currentChild != null) currentChild,
              ],
            );
          },
          transitionBuilder: (Widget child, Animation<double> animation) {
            final isIncoming = child.key == ValueKey('tab_${tab}_refresh_${_refreshKeyCounter}');

            if (!isIncoming) {
              // 💡 탭 이동 직후 이전 화면 위젯은 즉시 깨끗한 빈 화면(솔리드 배경)으로 세척
              return Container(
                color: const Color(0xfff4f7f5),
              );
            }

            // 💡 새로 생기는(등장하는) 화면만 깨끗한 빈 배경 위로 슬라이드 진입
            Offset inBeginOffset = Offset.zero;

            if (isMovingRight) {
              // 오른쪽 탭으로 이동 시: 새 탭이 우측(1.0)에서 좌측(0.0)으로 슬라이드 진입
              inBeginOffset = const Offset(1.0, 0.0);
            } else if (isMovingLeft) {
              // 왼쪽 탭으로 이동 시: 새 탭이 좌측(-1.0)에서 우측(0.0)으로 슬라이드 진입
              inBeginOffset = const Offset(-1.0, 0.0);
            }

            final offsetAnimation = Tween<Offset>(
              begin: inBeginOffset,
              end: Offset.zero,
            ).animate(animation);

            return SlideTransition(
              position: offsetAnimation,
              child: Material(
                color: const Color(0xfff4f7f5),
                child: child,
              ),
            );
          },
          child: KeyedSubtree(
            key: ValueKey('tab_${tab}_refresh_${_refreshKeyCounter}'),
            child: content(
              activePages[tab],
              refreshKey: _refreshKeyCounter, // 💡 새로고침 시 상단부터 순차대로 좌->우 위젯 연출 전달
              onRefresh: () async {
                try {
                  final authService = ref.read(authServiceProvider);
                  await authService.reloadUserProfile();
                  await ref.read(dataServiceProvider).refreshData(
                    token: authService.accessToken,
                    baseUrl: authService.baseUrl,
                  );
                  if (authService.isAdmin) {
                    await _loadAdminUsers();
                  }
                  if (mounted) {
                    setState(() {
                      _previousTab = tab;
                      _refreshKeyCounter++; // 🔥 새로고침 완료 시 즉시 흰색 세척 후 스태거드 순차 애니메이션 발동
                    });
                  }
                } catch (e) {
                  debugPrint('새로고침 수행 중 오류: $e');
                }
              },
            ),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: selectTab,
          destinations: [
            const NavigationDestination(icon: Icon(Icons.home_outlined), label: '홈'),
            NavigationDestination(
              icon: _buildNavIcon(Icons.chat_outlined, dataService.hasUnreadNewScenario),
              label: '상황극',
            ),
            NavigationDestination(
              icon: _buildNavIcon(Icons.insights, dataService.hasUnreadReport),
              label: '리포트',
            ),
            const NavigationDestination(icon: Icon(Icons.storefront), label: '운영규칙'),
            if (isAdmin)
              NavigationDestination(
                icon: _buildNavIcon(Icons.admin_panel_settings_outlined, dataService.hasUnreadCaseReview || dataService.hasUnreadAdminUserReports(adminUsers)),
                label: '관리자',
              ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: _buildSearchFABWrapper(tab != 4),
      ),
    );
  }

  // 관리자 전용 🔍 사례 검토 및 시나리오 변환 섹션 (삭제 & 변환 추가만 남기고 처리 건 자동 제거)
  Widget _buildAdminCaseReviewSection(DataService dataService) {
    // 이미 시나리오 변환/처리 완료된 건은 목록에서 완전 제거 (!isConvertedToScenario)
    final pendingCases = dataService.fieldCaseStore.where((c) => !c.isConvertedToScenario).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (dataService.hasUnreadCaseReview) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.notifications_active, color: Colors.red, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '🔔 [새로운 현장 사례 요청] 수습생이 작성한 신규 사례가 제출되었습니다. 확인해 주세요!',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red.shade900),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('검토 대기 현장 사례 (${pendingCases.length}건)', style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          '수습생이 제출한 현장 사례를 검토하여 시나리오로 변환하거나 삭제합니다. (처리 완료된 건은 목록에서 자동 제거됩니다)',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 14),

        if (pendingCases.isEmpty)
          const Card(
            child: ListTile(
              contentPadding: EdgeInsets.all(16),
              leading: Icon(Icons.check_circle_outline, size: 32, color: Colors.green),
              title: Text('대기 중인 검토 요청 사례가 없습니다.', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('모든 현장 사례가 처리되었거나 목록이 비어있습니다.'),
            ),
          )
        else
          for (final fieldCase in pendingCases)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Chip(label: Text(fieldCase.industry), padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            fieldCase.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        Chip(
                          label: const Text('검토 대기중 ⏳', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange)),
                          backgroundColor: Colors.orange.shade50,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('작성자: ${fieldCase.authorName} | 작성일: ${fieldCase.createdAt.toString().split(" ").first}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    const Divider(height: 18),
                    const Text('📍 발생 상황:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(fieldCase.situation, style: const TextStyle(fontSize: 13, height: 1.3)),
                    const SizedBox(height: 10),
                    const Text('🛠️ 현장 조치 내용:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(fieldCase.responseDetails, style: const TextStyle(fontSize: 13, height: 1.3, color: Colors.black87)),
                    const SizedBox(height: 14),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // 1. 사례 삭제 옵션
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: BorderSide(color: Colors.red.shade300),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: const Size(0, 36),
                          ),
                          onPressed: () => _confirmDeleteCase(fieldCase, dataService),
                          icon: const Icon(Icons.delete_outline, size: 16),
                          label: const Text('사례 삭제', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        // 2. 시나리오 변환/추가 옵션
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff146b59),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: const Size(0, 36),
                          ),
                          onPressed: () {
                            open(ScenarioForm(fromCase: fieldCase));
                          },
                          icon: const Icon(Icons.auto_awesome, size: 16),
                          label: const Text('시나리오 변환 추가', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
      ],
    );
  }

  void _confirmDeleteCase(FieldCase fieldCase, DataService dataService) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('현장 사례 삭제'),
        content: Text('정말로 [${fieldCase.title}] 사례를 삭제하시겠습니까?\n삭제된 사례는 검토 목록에서 제외됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              dataService.deleteFieldCase(fieldCase.id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('현장 사례가 삭제되었습니다.')),
              );
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  Widget _buildUserManagementSection(AuthService authService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('가입 회원 목록 (${adminUsers.length}명)', style: Theme.of(context).textTheme.titleLarge),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: const Size(0, 36),
              ),
              onPressed: _loadAdminUsers,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('새로고침'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text('가입된 수습생/관리자 유저의 상황극 진행 데이터/리포트를 열람하거나 계정을 삭제 관리합니다.', style: TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 14),

        if (isLoadingAdminUsers)
          const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
        else if (adminUsers.isEmpty)
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const Icon(Icons.people_outline, size: 32, color: Colors.grey),
              title: const Text('등록된 회원이 없습니다.', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('상단의 새로고침 버튼을 눌러 목록을 불러와 보세요.'),
            ),
          )
        else
          for (final user in adminUsers) ...[
            Builder(
              builder: (context) {
                final dataService = ref.watch(dataServiceProvider);
                final bool isUserUnread = dataService.isTraineeReportNew(user.id);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: user.isAdmin ? Colors.indigo.shade100 : Colors.teal.shade100,
                              child: Icon(
                                user.isAdmin ? Icons.admin_panel_settings : Icons.person,
                                color: user.isAdmin ? Colors.indigo : Colors.teal,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text('ID: ${user.id}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                            ),
                            Chip(
                              label: Text(
                                user.isAdmin ? '관리자' : '수습생',
                                style: TextStyle(
                                  color: user.isAdmin ? Colors.indigo : Colors.teal,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              backgroundColor: user.isAdmin ? Colors.indigo.shade50 : Colors.teal.shade50,
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          children: [
                            Icon(Icons.assignment_turned_in_outlined, size: 16, color: Colors.grey.shade700),
                            const SizedBox(width: 4),
                            Text('총 훈련: ${user.totalSessions}회', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 16),
                            Icon(Icons.star_outline, size: 16, color: Colors.grey.shade700),
                            const SizedBox(width: 4),
                            Text('평균 점수: ${user.averageScore}점', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        if (user.weaknessCategories.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            '취약 항목: ${user.weaknessCategories.join(", ")}',
                            style: const TextStyle(fontSize: 12, color: Colors.deepOrange, fontWeight: FontWeight.w600),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // 진행 데이터 열람 버튼 (새 훈련 데이터 존재 시 빨간 닷 🔴 표시)
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                minimumSize: const Size(0, 38),
                                side: isUserUnread ? BorderSide(color: Colors.red.shade300, width: 1.5) : null,
                              ),
                              onPressed: () {
                                dataService.markTraineeReportAsInspected(user.id);
                                open(AdminUserDetailView(user: user));
                              },
                              icon: _buildNavIcon(Icons.analytics_outlined, isUserUnread),
                              label: const Text('진행 데이터 열람', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            // 유저 삭제 버튼
                            if (authService.currentUser?.id != user.id)
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade600,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  minimumSize: const Size(0, 38),
                                ),
                                onPressed: () => _confirmDeleteUser(user),
                                icon: const Icon(Icons.delete_outline, size: 16),
                                label: const Text('유저 삭제', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
      ],
    );
  }

  void _confirmDeleteUser(UserModel user) {
    if (user.dbId == null) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('유저 계정 삭제'),
        content: Text('정말로 [${user.name} (${user.id})] 계정을 삭제하시겠습니까?\n해당 유저의 모든 훈련 진행 데이터도 함께 삭제됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final authService = ref.read(authServiceProvider);
              final success = await authService.deleteAdminUser(user.dbId!);
              if (!mounted) return;
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('유저 [${user.name}] 계정이 삭제되었습니다.')),
                );
                _loadAdminUsers();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('유저 계정 삭제 실패')),
                );
              }
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  Widget _buildLowScoreSection(DataService dataService) {
    if (dataService.practiceReports.isEmpty) {
      return Card(
        color: Colors.amber.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: CircleAvatar(
            backgroundColor: Colors.amber.shade200,
            child: const Icon(Icons.star_outline_rounded, color: Colors.amber),
          ),
          title: const Text('아직 연습한 상황극이 없습니다', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          subtitle: const Padding(
            padding: EdgeInsets.only(top: 4.0),
            child: Text('아래 추천 상황극이나 상황극 탭에서 첫 대화를 시작해 보세요!'),
          ),
        ),
      );
    }

    final lowReports = dataService.lowScoreLatestReports;

    if (lowReports.isEmpty) {
      return Card(
        color: Colors.green.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: CircleAvatar(
            backgroundColor: Colors.green.shade200,
            child: const Icon(Icons.emoji_events_outlined, color: Colors.green),
          ),
          title: const Text('우수한 대처 성과 달성 중!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          subtitle: const Padding(
            padding: EdgeInsets.only(top: 4.0),
            child: Text('모든 수행 상황극에서 80점 이상의 우수한 성적을 유지하고 있습니다.'),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 22),
            const SizedBox(width: 6),
            Text('보완이 필요한 상황극 (${lowReports.length}개)', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        const Text('최근 연습 점수가 80점 미만인 상황입니다. 재연습을 추천합니다!', style: TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 8),
        for (final report in lowReports)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _scoreColor(report.score).withValues(alpha: 0.15),
                child: Text('${report.score}점', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _scoreColor(report.score))),
              ),
              title: Text('${report.industry} · ${report.scenarioTitle}', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  '피드백: ${report.feedback}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onPressed: () {
                  final scenario = dataService.scenarioStore.firstWhere(
                    (s) => s.id == report.scenarioId,
                    orElse: () => dataService.scenarioStore.first,
                  );
                  startPractice(scenario);
                },
                child: const Text('재도전'),
              ),
            ),
          )
      ],
    );
  }

  List<Widget> _buildReportDashboard(DataService dataService) {
    final grouped = dataService.groupedReports;
    
    // 업종별 필터링
    final scenarioIds = grouped.keys.where((scenarioId) {
      if (selectedReportIndustry == '전체') return true;
      final reports = grouped[scenarioId]!;
      return reports.isNotEmpty && reports.first.industry == selectedReportIndustry;
    }).toList();

    // 카테고리/업종별 시나리오 리포트 그룹화 Map
    final Map<String, List<String>> groupedByIndustry = {};
    for (final scenarioId in scenarioIds) {
      final reports = grouped[scenarioId]!;
      final industryName = reports.isNotEmpty ? reports.first.industry : '기타';
      groupedByIndustry.putIfAbsent(industryName, () => []).add(scenarioId);
    }

    return [
      Text('교육 리포트 대시보드', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 6),
      const Text('상황극별 연습 히스토리와 회차별 성과 변화를 비교할 수 있습니다.'),
      const SizedBox(height: 14),

      // 📈 전체 회차별 점수 변화 가시적 그래프
      if (dataService.practiceReports.isNotEmpty) ...[
        ScoreTrendChart(reports: dataService.practiceReports),
        const SizedBox(height: 16),
      ],

      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final industry in ['전체', '카페', '편의점', '식당'])
            ChoiceChip(
              label: Text(industry),
              selected: selectedReportIndustry == industry,
              onSelected: (_) => setState(() => selectedReportIndustry = industry),
            ),
        ],
      ),
      const SizedBox(height: 16),
      if (scenarioIds.isEmpty)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const Icon(Icons.assignment_late_outlined, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                const Text('해당 업종의 완료된 상황극 연습이 없습니다.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('상황극 탭으로 이동하여 실제 연습을 진행해 보세요!', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => selectTab(1),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('상황극 둘러보기'),
                )
              ],
            ),
          ),
        )
      else
        for (final category in groupedByIndustry.keys) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(_industryIcon(category), size: 20, color: const Color(0xff146b59)),
              const SizedBox(width: 8),
              Text(
                '$category 리포트 (${groupedByIndustry[category]!.length}개)',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final scenarioId in groupedByIndustry[category]!) ...[
            _buildScenarioReportSummaryCard(dataService, scenarioId),
            const SizedBox(height: 8),
          ]
        ]
    ];
  }

  Widget _buildScenarioReportSummaryCard(DataService dataService, String scenarioId) {
    final reports = dataService.groupedReports[scenarioId]!;
    final latestReport = reports.first;
    final oldestReport = reports.last;
    final scoreDiff = latestReport.score - oldestReport.score;
    final bool isUnread = dataService.isScenarioReportsNew(scenarioId);

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              backgroundColor: _scoreColor(latestReport.score).withValues(alpha: 0.15),
              child: Icon(_industryIcon(latestReport.industry), color: _scoreColor(latestReport.score)),
            ),
            if (isUnread)
              const Positioned(
                right: -2,
                top: -2,
                child: CircleAvatar(
                  radius: 4.5,
                  backgroundColor: Colors.red,
                ),
              ),
          ],
        ),
        title: Text('${latestReport.industry} · ${latestReport.scenarioTitle}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('총 ${reports.length}회 연습 | 최근 점수: ${latestReport.score}점'),
              const SizedBox(height: 4),
              Text(
                '최근 피드백: ${latestReport.feedback}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              if (latestReport.adminComment != null && latestReport.adminComment!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '관리자 코멘트: ${latestReport.adminComment}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.indigo, fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _scoreColor(latestReport.score),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('${latestReport.score}점', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            if (reports.length > 1) ...[
              const SizedBox(height: 4),
              Text(
                scoreDiff >= 0 ? '+${scoreDiff}점 상승' : '${scoreDiff}점 하락',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: scoreDiff >= 0 ? Colors.green.shade800 : Colors.red.shade800,
                ),
              ),
            ]
          ],
        ),
        onTap: () {
          dataService.markReportsAsReadForScenario(scenarioId);
          open(ReportDetailView(scenarioId: scenarioId));
        },
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score >= 90) return Colors.green.shade600;
    if (score < 70) return Colors.red.shade600;
    return Colors.orange.shade700;
  }

  IconData _industryIcon(String industry) => switch (industry) {
    '카페' => Icons.local_cafe_outlined,
    '편의점' => Icons.storefront_outlined,
    '식당' => Icons.restaurant_outlined,
    _ => Icons.work_outline,
  };

  Widget _adminScenarioCard(RoleplayScenario scenario, DataService dataService, AuthService authService) => Card(
    child: ListTile(
      leading: Icon(scenario.isPublished ? Icons.public : Icons.edit_note),
      title: Text('${scenario.industry} · ${scenario.title}'),
      subtitle: Text('${scenario.isPublished ? '공개' : '초안'} · ${scenario.situation}', maxLines: 2, overflow: TextOverflow.ellipsis),
      onTap: () => open(ScenarioForm(existing: scenario)),
      trailing: PopupMenuButton<String>(
        onSelected: (action) {
          if (action == 'toggle') {
            dataService.toggleScenarioPublished(
              scenario.id,
              token: authService.accessToken,
              baseUrl: authService.baseUrl,
            );
          }
          if (action == 'delete') {
            dataService.removeScenario(
              scenario.id,
              token: authService.accessToken,
              baseUrl: authService.baseUrl,
            );
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: 'toggle', child: Text(scenario.isPublished ? '초안으로 변경' : '공개하기')),
          const PopupMenuItem(value: 'delete', child: Text('삭제')),
        ],
      ),
    ),
  );
}
