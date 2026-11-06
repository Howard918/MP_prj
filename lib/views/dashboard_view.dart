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
import 'scenario_form_view.dart';
import 'session_setup_view.dart';

class Dashboard extends ConsumerStatefulWidget {
  const Dashboard({super.key});
  @override
  ConsumerState<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends ConsumerState<Dashboard> {
  int tab = 0;
  int adminSubTab = 0; // 0: 시나리오 관리, 1: 사례 검토 및 변환, 2: 유저 회원 관리
  String selectedIndustry = '전체';
  String selectedReportIndustry = '전체';

  List<UserModel> adminUsers = [];
  bool isLoadingAdminUsers = false;
  bool _isRefreshing = false; // 새로고침 중 상호작용 차단 및 로딩 모달 상태

  @override
  void initState() {
    super.initState();
    // 앱 진입 시 1. 시나리오 데이터 로드 ➔ 2. 유저별 독립 알림 동기화 ➔ 3. 백엔드 리포트 패치
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final dataService = ref.read(dataServiceProvider);
      final authService = ref.read(authServiceProvider);

      await dataService.loadData(baseUrl: authService.baseUrl);

      if (authService.currentUser != null) {
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

    setState(() {
      tab = index;
    });

    final dataService = ref.read(dataServiceProvider);

    if (index == 4) {
      // 관리자 탭 클릭 시
      _loadAdminUsers();
      if (adminSubTab == 1) {
        dataService.clearCaseReviewNotification();
      }
    }
  }

  void _logout() {
    if (_isRefreshing) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              final dataService = ref.read(dataServiceProvider);
              ref.read(authServiceProvider).logout(dataService);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginView()),
              );
            },
            child: const Text('로그아웃'),
          )
        ],
      ),
    );
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
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? const Color(0xff146b59) : Colors.grey.shade700,
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

      // 3번 탭: 매장 운영규칙
      [
        panel('매장 운영규칙', '상황극에 연결할 규칙 예시를 확인하세요.', Icons.menu_book, () => open(const RulesPage())),
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (tab != 0) {
          // 홈 탭이 아닌 다른 탭에 있을 경우 홈 탭(0번)으로 이동
          setState(() {
            tab = 0;
          });
        } else {
          // 홈 탭일 경우 앱 종료 여부 확인 팝업 표시
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
        body: Stack(
          children: [
            content(
              activePages[tab],
              onRefresh: () async {
                if (_isRefreshing) return;
                setState(() {
                  _isRefreshing = true;
                });

                try {
                  final authService = ref.read(authServiceProvider);
                  await authService.reloadUserProfile(); // 🔥 사용자 최신 통계(평균 점수, 훈련 횟수 등) 업데이트 연동
                  await ref.read(dataServiceProvider).refreshData(
                    token: authService.accessToken,
                    baseUrl: authService.baseUrl,
                  );
                  if (authService.isAdmin) {
                    await _loadAdminUsers();
                  }
                } finally {
                  if (mounted) {
                    setState(() {
                      _isRefreshing = false;
                    });
                  }
                }
              },
            ),
            // 새로고침 진행 중 유저 상호작용 완전 차단 모달 베리어
            if (_isRefreshing)
              ModalBarrier(
                dismissible: false,
                color: Colors.black.withValues(alpha: 0.15),
              ),
            if (_isRefreshing)
              const Center(
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                        SizedBox(width: 12),
                        Text(
                          '데이터 동기화 중...',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
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
      const SizedBox(height: 16),
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
