import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../models/practice_report.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';

class AdminUserDetailView extends ConsumerStatefulWidget {
  final UserModel user;
  const AdminUserDetailView({super.key, required this.user});

  @override
  ConsumerState<AdminUserDetailView> createState() => _AdminUserDetailViewState();
}

class _AdminUserDetailViewState extends ConsumerState<AdminUserDetailView> {
  List<PracticeReport> userReports = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserReports();
  }

  Future<void> _loadUserReports() async {
    if (widget.user.dbId == null) {
      setState(() => isLoading = false);
      return;
    }
    final authService = ref.read(authServiceProvider);
    final reports = await authService.fetchAdminUserReports(widget.user.dbId!);
    if (mounted) {
      setState(() {
        userReports = reports;
        isLoading = false;
      });
    }
  }

  void _showAdminCommentDialog(PracticeReport report) {
    final commentController = TextEditingController(text: report.adminComment ?? '');

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('관리자 피드백 코멘트 작성'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('상황극: [${report.scenarioTitle}]', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text('수습생: ${widget.user.name} | 대처 점수: ${report.score}점', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 14),
            TextField(
              controller: commentController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: '관리자 코멘트 (수습생 리포트에 노출됨)',
                hintText: '예: 사과 조치가 신속하고 정중했습니다. 다음에는 대안 제안을 조금 더 일찍 해보세요!',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xff146b59)),
            onPressed: () async {
              final oldComment = (report.adminComment ?? '').trim();
              final newComment = commentController.text.trim();

              // 기존 코멘트 내용과 완전 동일한 경우 저장 및 알림 발동 없이 즉시 팝업 닫기!
              if (oldComment == newComment) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('코멘트 내용에 변경 사항이 없어 기존 상태를 유지합니다.')),
                );
                return;
              }

              Navigator.pop(ctx);

              final authService = ref.read(authServiceProvider);
              final dataService = ref.read(dataServiceProvider);
              final reportDbId = int.tryParse(report.id);

              if (reportDbId != null) {
                final success = await authService.updateAdminReportComment(reportDbId, newComment);
                if (success) {
                  setState(() {
                    report.adminComment = newComment;
                  });
                  // 해당 수습생 유저에게 [리포트 탭 🔴] 알림 트리거!
                  dataService.setAdminReportComment(report.id, newComment, widget.user.id);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('관리자 피드백 코멘트가 저장되었으며 해당 유저에게 알림이 전송되었습니다!')),
                    );
                  }
                  return;
                }
              }

              // 로컬 반영 폴백
              setState(() {
                report.adminComment = newComment;
              });
              dataService.setAdminReportComment(report.id, newComment, widget.user.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('관리자 피드백 코멘트가 반영되었으며 해당 유저에게 알림이 전송되었습니다.')),
                );
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteReport(PracticeReport report) {
    final int reportDbId = int.tryParse(report.id) ?? -1;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text('훈련 리포트 삭제', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          '[${report.scenarioTitle}] (${report.score}점) 훈련 리포트를 정말로 삭제하시겠습니까?\n삭제 후 유저의 평균 점수 및 총 훈련 횟수가 자동 재계산됩니다.',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
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
              final success = await authService.deleteAdminReport(reportDbId);
              if (mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('훈련 리포트가 성공적으로 삭제되었습니다.')),
                  );
                  _loadUserReports(); // 리포트 목록 및 유저 통계 재패치
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('훈련 리포트 삭제 중 오류가 발생했습니다.')),
                  );
                }
              }
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  void _showDialogueModal(PracticeReport report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (_, scrollController) => Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${report.industry} · ${report.scenarioTitle}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    )
                  ],
                ),
                Text(
                  '수행 일시: ${report.dateTime.toString().split('.').first} | 대처 점수: ${report.score}점',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 12),
                
                // AI 평가 피드백 카드
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('AI 평가 피드백: ${report.feedback}', style: const TextStyle(fontSize: 13)),
                ),
                const SizedBox(height: 10),

                // 관리자 피드백 코멘트 카드 & 작성/수정 버튼
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.indigo.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.admin_panel_settings, size: 18, color: Colors.indigo),
                              SizedBox(width: 6),
                              Text('매장 점주/관리자 피드백', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.indigo)),
                            ],
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              minimumSize: const Size(0, 32),
                            ),
                            onPressed: () {
                              _showAdminCommentDialog(report);
                              setModalState(() {});
                            },
                            icon: const Icon(Icons.edit, size: 14),
                            label: Text(
                              report.adminComment != null && report.adminComment!.isNotEmpty ? '코멘트 수정' : '코멘트 작성',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        report.adminComment != null && report.adminComment!.isNotEmpty
                            ? report.adminComment!
                            : '아직 작성된 관리자 피드백 코멘트가 없습니다. [코멘트 작성] 버튼을 눌러 남겨보세요!',
                        style: TextStyle(
                          fontSize: 13,
                          color: report.adminComment != null && report.adminComment!.isNotEmpty ? Colors.indigo.shade900 : Colors.grey.shade600,
                          fontWeight: report.adminComment != null && report.adminComment!.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                          fontStyle: report.adminComment == null || report.adminComment!.isEmpty ? FontStyle.italic : FontStyle.normal,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                const Text('대화 기록 내역 (트랜스크립트)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: report.dialogueHistory.length,
                    itemBuilder: (_, index) {
                      final msg = report.dialogueHistory[index];
                      final isUser = msg.role == 'user';
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isUser ? const Color(0xff146b59) : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${isUser ? "수습생" : "고객 AI"}: ${msg.content}',
                            style: TextStyle(
                              color: isUser ? Colors.white : Colors.black87,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;

    // 1. 코멘트 작성이 필요한 상황극 리포트 목록 (우선순위 1순위: 코멘트 없음 & 낮음 점수/최신순)
    final reportsNeedingComment = userReports.where((r) =>
        r.adminComment == null || r.adminComment!.trim().isEmpty
    ).toList();

    reportsNeedingComment.sort((a, b) {
      if (a.score != b.score) return a.score.compareTo(b.score); // 오름차순 (낮은 점수 우선)
      return b.dateTime.compareTo(a.dateTime); // 최신순
    });

    // 2. 카테고리(업종)별 ➔ 상황극(scenarioId)별 그룹화 대시보드 Map
    final Map<String, Map<String, List<PracticeReport>>> categoryGroupedReports = {};
    for (final r in userReports) {
      final category = r.industry.trim().isNotEmpty ? r.industry.trim() : '기타';
      final scenarioId = r.scenarioId.trim().isNotEmpty ? r.scenarioId.trim() : r.scenarioTitle;
      categoryGroupedReports.putIfAbsent(category, () => {});
      categoryGroupedReports[category]!.putIfAbsent(scenarioId, () => []).add(r);
    }

    // 각 상황극별 회차 정렬 (최신순)
    for (final catMap in categoryGroupedReports.values) {
      for (final reportList in catMap.values) {
        reportList.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text('${user.name} 훈련 분석 대시보드')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 프로필 요약 카드
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(18.0),
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
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            Text('ID: ${user.id}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                        const Spacer(),
                        Chip(
                          label: Text(
                            user.isAdmin ? '관리자' : '수습생',
                            style: TextStyle(
                              color: user.isAdmin ? Colors.indigo : Colors.teal,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor: user.isAdmin ? Colors.indigo.shade50 : Colors.teal.shade50,
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _statColumn('총 훈련 횟수', '${user.totalSessions}회'),
                        _statColumn('평균 대처 점수', '${user.averageScore}점'),
                      ],
                    ),
                    if (user.weaknessCategories.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('취약 조치 카테고리:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final weakness in user.weaknessCategories)
                            Chip(
                              label: Text(weakness, style: const TextStyle(fontSize: 12, color: Colors.deepOrange)),
                              backgroundColor: Colors.deepOrange.shade50,
                              side: BorderSide(color: Colors.deepOrange.shade200),
                            ),
                        ],
                      ),
                    ]
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            if (isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
            else if (userReports.isEmpty)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.assignment_outlined, color: Colors.grey),
                  title: Text('아직 수행한 상황극 훈련 기록이 없습니다.'),
                ),
              )
            else ...[
              // 1순위: 관리자 피드백 코멘트 작성이 필요한 상황극 섹션
              Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.deepOrange, size: 22),
                  const SizedBox(width: 6),
                  Text(
                    '피드백 코멘트가 필요한 상황극 (${reportsNeedingComment.length}건)',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                '수습생에게 관리자의 직접 조언이나 피드백 코멘트가 아직 전달되지 않은 항목입니다.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 12),

              if (reportsNeedingComment.isEmpty)
                Card(
                  color: Colors.green.shade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: const ListTile(
                    leading: Icon(Icons.check_circle_outline, color: Colors.green, size: 28),
                    title: Text('모든 수행 상황극에 피드백 코멘트가 검토 완료되었습니다!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text('모든 리포트에 관리자 코멘트가 수습생에게 전달되고 있습니다.'),
                  ),
                )
              else
                for (final report in reportsNeedingComment)
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: Colors.deepOrange.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Chip(
                                label: Text(report.industry, style: const TextStyle(fontSize: 11)),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  report.scenarioTitle,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _scoreColor(report.score),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text('${report.score}점', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('수행 일시: ${report.dateTime.toString().split('.').first}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('AI 피드백: ${report.feedback}', style: const TextStyle(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  minimumSize: const Size(0, 36),
                                ),
                                onPressed: () => _confirmDeleteReport(report),
                                icon: const Icon(Icons.delete_outline, size: 16),
                                label: const Text('삭제', style: TextStyle(fontSize: 12)),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  minimumSize: const Size(0, 36),
                                ),
                                onPressed: () => _showDialogueModal(report),
                                icon: const Icon(Icons.forum_outlined, size: 16),
                                label: const Text('대화 기록', style: TextStyle(fontSize: 12)),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xff146b59),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  minimumSize: const Size(0, 36),
                                ),
                                onPressed: () => _showAdminCommentDialog(report),
                                icon: const Icon(Icons.edit_note, size: 16),
                                label: const Text('코멘트 작성', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),

              // 2순위: 카테고리별 성과 분석 대시보드
              const SizedBox(height: 28),
              const Row(
                children: [
                  Icon(Icons.dashboard_customize_outlined, color: Color(0xff146b59), size: 22),
                  SizedBox(width: 6),
                  Text('카테고리별 훈련 성과 대시보드', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              const Text('업종 카테고리별 상황극 수행 회차, 최근 점수 및 회차별 성과 변화입니다.', style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 14),

              for (final category in categoryGroupedReports.keys) ...[
                _buildCategoryDashboardCard(category, categoryGroupedReports[category]!),
                const SizedBox(height: 16),
              ]
            ],
          ],
        ),
      ),
    );
  }

  // 업종 카테고리별 훈련 분석 카드 대시보드
  Widget _buildCategoryDashboardCard(String category, Map<String, List<PracticeReport>> scenarioMap) {
    // 카테고리 전체 총 훈련 횟수 및 평균 점수 계산
    int totalCount = 0;
    int totalScoreSum = 0;
    for (final reportList in scenarioMap.values) {
      totalCount += reportList.length;
      for (final r in reportList) {
        totalScoreSum += r.score;
      }
    }
    final double categoryAvgScore = totalCount > 0 ? (totalScoreSum / totalCount) : 0.0;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 카테고리 헤더
            Row(
              children: [
                Icon(_industryIcon(category), size: 22, color: const Color(0xff146b59)),
                const SizedBox(width: 8),
                Text(
                  '$category 카테고리',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
                const Spacer(),
                Chip(
                  label: Text('총 ${totalCount}회 · 평균 ${categoryAvgScore.toStringAsFixed(1)}점', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  backgroundColor: const Color(0xff146b59).withValues(alpha: 0.1),
                  side: BorderSide.none,
                )
              ],
            ),
            const Divider(height: 20),

            // 각 상황극별 회차 분석 및 점수 변화
            for (final scenarioId in scenarioMap.keys) ...[
              Builder(
                builder: (context) {
                  final reports = scenarioMap[scenarioId]!;
                  final latestReport = reports.first;
                  final oldestReport = reports.last;
                  final scoreDiff = latestReport.score - oldestReport.score;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                latestReport.scenarioTitle,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _scoreColor(latestReport.score),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text('최근 ${latestReport.score}점', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text('총 ${reports.length}회 수행', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            if (reports.length > 1) ...[
                              const SizedBox(width: 10),
                              Text(
                                scoreDiff >= 0 ? '+${scoreDiff}점 상승' : '${scoreDiff}점 하락',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: scoreDiff >= 0 ? Colors.green.shade800 : Colors.red.shade800,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const Divider(height: 16),

                        // 회차별 히스토리
                        for (int i = 0; i < reports.length; i++) ...[
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              radius: 14,
                              backgroundColor: _scoreColor(reports[i].score).withValues(alpha: 0.15),
                              child: Text('${reports.length - i}회', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _scoreColor(reports[i].score))),
                            ),
                            title: Text('수행일: ${reports[i].dateTime.toString().split('.').first}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            subtitle: Text('피드백: ${reports[i].feedback}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${reports[i].score}점', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _scoreColor(reports[i].score))),
                                const SizedBox(width: 2),
                                IconButton(
                                  icon: const Icon(Icons.forum_outlined, size: 18),
                                  tooltip: '대화 기록',
                                  onPressed: () => _showDialogueModal(reports[i]),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                  tooltip: '리포트 삭제',
                                  onPressed: () => _confirmDeleteReport(reports[i]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statColumn(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ],
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
}
