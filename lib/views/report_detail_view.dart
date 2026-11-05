import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/practice_report.dart';
import '../models/roleplay_scenario.dart';
import '../services/data_service.dart';
import 'session_setup_view.dart';

class ReportDetailView extends ConsumerWidget {
  final String scenarioId;

  const ReportDetailView({required this.scenarioId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataService = ref.watch(dataServiceProvider);
    final reports = dataService.getReportsForScenario(scenarioId);

    if (reports.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('연습 리포트 상세')),
        body: const Center(child: Text('해당 상황극의 연습 기록이 없습니다.')),
      );
    }

    final latestReport = reports.first; // 최신 회차
    final oldestReport = reports.last;  // 최초 회차
    final scoreDiff = latestReport.score - oldestReport.score;
    final bestScore = reports.map((r) => r.score).reduce((a, b) => a > b ? a : b);

    // 해당 시나리오 객체 찾기
    final scenario = dataService.scenarioStore.firstWhere(
      (s) => s.id == scenarioId,
      orElse: () => RoleplayScenario(
        id: scenarioId,
        industry: latestReport.industry,
        title: latestReport.scenarioTitle,
        situation: '',
        expectedActions: '',
        linkedRules: '',
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('상황극 리포트 & 성과 비교'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header Card
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Chip(label: Text('${latestReport.industry} · 성과 비교')),
                  const SizedBox(height: 8),
                  Text(
                    latestReport.scenarioTitle,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '총 ${reports.length}회 연습함 | 최고 점수: $bestScore점',
                    style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 비교 메커니즘 카드 (Comparison Summary Card)
          if (reports.length > 1)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.trending_up, color: Colors.green, size: 24),
                        SizedBox(width: 8),
                        Text('회차별 점수 향상 비교', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text('최초 (1회차)', style: TextStyle(color: Colors.grey, fontSize: 13)),
                            const SizedBox(height: 4),
                            Text('${oldestReport.score}점', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Icon(Icons.arrow_forward_rounded, color: Colors.grey),
                        Column(
                          children: [
                            const Text('최근 (최신)', style: TextStyle(color: Colors.grey, fontSize: 13)),
                            const SizedBox(height: 4),
                            Text('${latestReport.score}점', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _scoreColor(latestReport.score))),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: scoreDiff >= 0 ? Colors.green.shade100 : Colors.red.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            scoreDiff >= 0 ? '+${scoreDiff}점 상승' : '${scoreDiff}점 하락',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: scoreDiff >= 0 ? Colors.green.shade800 : Colors.red.shade800,
                            ),
                          ),
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('회차별 연습 히스토리 (${reports.length}개)', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SessionSetupView(scenario: scenario)),
                  );
                },
                icon: const Icon(Icons.replay_rounded, size: 18),
                label: const Text('다시 연습하기'),
              )
            ],
          ),
          const SizedBox(height: 12),

          // 회차별 상세 리포트 목록
          for (int index = 0; index < reports.length; index++)
            _buildAttemptCard(context, ref, dataService, reports[index], reports.length - index),
        ],
      ),
    );
  }

  Widget _buildAttemptCard(BuildContext context, WidgetRef ref, DataService dataService, PracticeReport report, int attemptNum) {
    final formattedDate = '${report.dateTime.year}.${report.dateTime.month.toString().padLeft(2, '0')}.${report.dateTime.day.toString().padLeft(2, '0')} ${report.dateTime.hour.toString().padLeft(2, '0')}:${report.dateTime.minute.toString().padLeft(2, '0')}';
    final bool isUnread = dataService.isReportNew(report.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          backgroundColor: _scoreColor(report.score).withValues(alpha: 0.15),
                          child: Text('$attemptNum회', style: TextStyle(fontWeight: FontWeight.bold, color: _scoreColor(report.score))),
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
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$attemptNum회차 연습 결과', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(formattedDate, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: _scoreColor(report.score),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${report.score}점',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                )
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('AI 평가 피드백', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                  const SizedBox(height: 4),
                  Text(report.feedback, style: const TextStyle(fontSize: 14, height: 1.4)),
                ],
              ),
            ),
            if (report.adminComment != null && report.adminComment!.isNotEmpty) ...[
              const SizedBox(height: 8),
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
                    const Row(
                      children: [
                        Icon(Icons.admin_panel_settings, size: 18, color: Colors.indigo),
                        SizedBox(width: 6),
                        Text('매장 점주/관리자 피드백 코멘트', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(report.adminComment!, style: const TextStyle(fontSize: 14, height: 1.4, color: Colors.indigo, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),

            // 접었다 펼칠 수 있는 상황극 대화 내용 (Full Dialogue History)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              onExpansionChanged: (expanded) {
                if (expanded) {
                  dataService.markReportAsRead(report.id);
                }
              },
              title: Text('대화 내용 전체 보기 (${report.dialogueHistory.length}턴)', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.green)),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      for (final msg in report.dialogueHistory)
                        Align(
                          alignment: msg.role == 'user' ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: msg.role == 'user' ? Colors.green[100] : Colors.grey[200],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: msg.role == 'user' ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                Text(
                                  msg.role == 'user' ? '나 (알바생)' : '고객',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54),
                                ),
                                const SizedBox(height: 2),
                                Text(msg.content, style: const TextStyle(fontSize: 14)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score >= 90) return Colors.green.shade600;
    if (score < 70) return Colors.red.shade600;
    return Colors.orange.shade700;
  }
}
