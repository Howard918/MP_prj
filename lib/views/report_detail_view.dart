import 'dart:math' as math;
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

          // 📈 회차별 점수 변화 시각적 그래프 카드
          ScoreTrendChart(reports: reports),
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
              Expanded(
                child: Text('회차별 연습 히스토리 (${reports.length}개)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
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

// 🌟 리포트 메인 대시보드 전용: 동적 카테고리별 평균 점수 막대 그래프 위젯 (오버플로우 제로 & 유동적 카테고리 변동 대응)
class CategoryScoreBarChart extends StatelessWidget {
  final DataService dataService;

  const CategoryScoreBarChart({super.key, required this.dataService});

  Color _scoreColor(double score) {
    if (score >= 90) return Colors.green.shade600;
    if (score < 70) return Colors.red.shade600;
    return Colors.orange.shade700;
  }

  IconData _categoryIcon(String category) => switch (category) {
    '음료/메뉴' => Icons.local_cafe_outlined,
    '고객 서비스' => Icons.sentiment_satisfied_alt_outlined,
    '안전/비상대응' => Icons.health_and_safety_outlined,
    '위생/식품안전' => Icons.sanitizer_outlined,
    'POS/금전정산' => Icons.point_of_sale_outlined,
    '시설/장비관리' => Icons.build_circle_outlined,
    _ => Icons.category_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final categories = dataService.categories;
    final allReports = dataService.currentUserReports;

    if (allReports.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Center(child: Text('저장된 훈련 리포트가 없습니다.')),
        ),
      );
    }

    final double overallAvg = allReports.map((r) => r.score).reduce((a, b) => a + b) / allReports.length;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.bar_chart_rounded, color: Color(0xff146b59), size: 22),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '업무 카테고리별 평균 성과',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xff146b59).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '전체 평균 ${overallAvg.toStringAsFixed(1)}점',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xff146b59)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              '동적 업무 카테고리별 훈련 회차와 평균 점수를 분석한 막대 그래프입니다.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 18),

            for (final cat in categories) ...[
              Builder(
                builder: (context) {
                  final catReports = allReports.where((r) => r.category == cat || r.scenarioTitle.contains(cat)).toList();
                  final count = catReports.length;
                  final double avgScore = count > 0
                      ? (catReports.map((r) => r.score).reduce((a, b) => a + b) / count)
                      : 0.0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(_categoryIcon(cat), size: 18, color: const Color(0xff146b59)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                cat,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.black87),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (count > 0)
                              Text(
                                '${avgScore.toStringAsFixed(1)}점 (${count}회)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                  color: _scoreColor(avgScore),
                                ),
                              )
                            else
                              const Text(
                                '미수행',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final maxBarWidth = constraints.maxWidth;
                            final fillWidth = count > 0 ? (maxBarWidth * (avgScore / 100.0)).clamp(8.0, maxBarWidth) : 0.0;

                            return Stack(
                              children: [
                                Container(
                                  height: 12,
                                  width: maxBarWidth,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.grey.shade300, width: 0.5),
                                  ),
                                ),
                                if (count > 0)
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 400),
                                    height: 12,
                                    width: fillWidth,
                                    decoration: BoxDecoration(
                                      color: _scoreColor(avgScore),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
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
}

class ScoreTrendChart extends StatelessWidget {
  final List<PracticeReport> reports;

  const ScoreTrendChart({super.key, required this.reports});

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Center(child: Text('저장된 훈련 리포트가 없습니다.')),
        ),
      );
    }

    // 날짜 오름차순 정렬 (회차 1부터 N까지 시순)
    final sorted = List<PracticeReport>.from(reports)
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    final scores = sorted.map((r) => r.score).toList();
    final avgScore = scores.reduce((a, b) => a + b) / scores.length;
    final maxScore = scores.reduce((a, b) => a > b ? a : b);
    final minScore = scores.reduce((a, b) => a < b ? a : b);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.show_chart_rounded, color: Color(0xff146b59), size: 22),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '회차별 점수 변화 그래프',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xff146b59).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '평균 ${avgScore.toStringAsFixed(1)}점',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xff146b59)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildMetricChip('총 훈련', '${sorted.length}회차', Colors.blue),
                  const SizedBox(width: 6),
                  _buildMetricChip('최고 점수', '$maxScore점', Colors.green),
                  const SizedBox(width: 6),
                  _buildMetricChip('최저 점수', '$minScore점', Colors.orange),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 170,
              width: double.infinity,
              child: CustomPaint(
                painter: _ScoreChartPainter(scores: scores),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 11, color: Colors.black54)),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class _ScoreChartPainter extends CustomPainter {
  final List<int> scores;

  _ScoreChartPainter({required this.scores});

  @override
  void paint(Canvas canvas, Size size) {
    if (scores.isEmpty) return;

    final paintGrid = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 1.0;

    final paintLine = Paint()
      ..color = const Color(0xff146b59)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paintFill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xff146b59).withValues(alpha: 0.25),
          const Color(0xff146b59).withValues(alpha: 0.01),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final paintDot = Paint()
      ..color = const Color(0xff146b59)
      ..style = PaintingStyle.fill;

    final paintDotBorder = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    const topPadding = 24.0;
    const bottomPadding = 24.0;
    final chartHeight = size.height - topPadding - bottomPadding;

    // Y축 가이드 라인 (0, 50, 100점)
    for (int yVal in [0, 50, 100]) {
      final y = size.height - bottomPadding - (yVal / 100.0) * chartHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paintGrid);

      final textPainter = TextPainter(
        text: TextSpan(text: '$yVal', style: TextStyle(fontSize: 9, color: Colors.grey.shade400)),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(0, y - 12));
    }

    final count = scores.length;
    final points = <Offset>[];

    for (int i = 0; i < count; i++) {
      final x = count == 1 ? size.width / 2 : (i / (count - 1)) * (size.width - 32) + 16;
      final y = size.height - bottomPadding - (scores[i] / 100.0) * chartHeight;
      points.add(Offset(x, y));
    }

    // 영역 그래디언트 면적 채우기
    if (points.length > 1) {
      final pathFill = Path()..moveTo(points.first.dx, size.height - bottomPadding);
      for (final p in points) {
        pathFill.lineTo(p.dx, p.dy);
      }
      pathFill.lineTo(points.last.dx, size.height - bottomPadding);
      pathFill.close();
      canvas.drawPath(pathFill, paintFill);
    }

    // 연결 선 그리기
    if (points.length > 1) {
      final pathLine = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        pathLine.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(pathLine, paintLine);
    }

    // 각 점(데이터 노드) 및 점수/회차 텍스트 렌더링
    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final score = scores[i];

      canvas.drawCircle(p, 5.5, paintDot);
      canvas.drawCircle(p, 2.5, paintDotBorder);

      final scorePainter = TextPainter(
        text: TextSpan(
          text: '$score점',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xff146b59)),
        ),
        textDirection: TextDirection.ltr,
      );
      scorePainter.layout();
      scorePainter.paint(canvas, Offset(p.dx - scorePainter.width / 2, p.dy - 16));

      final labelPainter = TextPainter(
        text: TextSpan(
          text: '${i + 1}회',
          style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600),
        ),
        textDirection: TextDirection.ltr,
      );
      labelPainter.layout();
      labelPainter.paint(canvas, Offset(p.dx - labelPainter.width / 2, size.height - 18));
    }
  }

  @override
  bool shouldRepaint(covariant _ScoreChartPainter oldDelegate) => oldDelegate.scores != scores;
}
