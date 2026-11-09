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

// 🌟 메인 리포트 대시보드 전용: 상황극별 평균 점수 다각형 역량표시 레이더 차트
class CompetencyRadarChart extends StatelessWidget {
  final DataService dataService;

  const CompetencyRadarChart({super.key, required this.dataService});

  @override
  Widget build(BuildContext context) {
    if (dataService.practiceReports.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Center(child: Text('저장된 훈련 리포트가 없습니다.')),
        ),
      );
    }

    // 상황극 타이틀별 수행 평균 점수 산출
    final Map<String, double> scenarioScores = {};
    for (final report in dataService.practiceReports) {
      final title = report.scenarioTitle;
      if (!scenarioScores.containsKey(title)) {
        final matches = dataService.practiceReports.where((r) => r.scenarioTitle == title);
        final avg = matches.map((r) => r.score).reduce((a, b) => a + b) / matches.length;
        scenarioScores[title] = avg;
      }
    }

    // 풍부한 다각형 역량 지표 구성을 위해 미수행 시나리오 축 보완 (최소 3~4개 축 유도)
    if (scenarioScores.length < 3) {
      for (final s in dataService.scenarioStore) {
        if (!scenarioScores.containsKey(s.title)) {
          scenarioScores[s.title] = 0.0;
          if (scenarioScores.length >= 4) break;
        }
      }
    }

    final entries = scenarioScores.entries.toList();
    final double overallAvg = entries.where((e) => e.value > 0).isNotEmpty
        ? entries.where((e) => e.value > 0).map((e) => e.value).reduce((a, b) => a + b) /
            entries.where((e) => e.value > 0).length
        : 0.0;

    return Card(
      elevation: 2.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.pentagon_outlined, color: Color(0xff146b59), size: 22),
                    SizedBox(width: 8),
                    Text('상황극별 역량 다각형 분석', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xff146b59).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '평균 ${overallAvg.toStringAsFixed(1)}점',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xff146b59)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              '각 상황극별 수행 평균 점수를 다각형 역량 지표로 종합 분석한 차트입니다.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 230,
              width: double.infinity,
              child: CustomPaint(
                painter: _RadarChartPainter(scores: scenarioScores),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadarChartPainter extends CustomPainter {
  final Map<String, double> scores;

  _RadarChartPainter({required this.scores});

  @override
  void paint(Canvas canvas, Size size) {
    if (scores.isEmpty) return;

    final entries = scores.entries.toList();
    final count = entries.length;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - 38;

    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final axisLinePaint = Paint()
      ..color = const Color(0xff146b59).withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final dataFillPaint = Paint()
      ..color = const Color(0xff146b59).withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    final dataStrokePaint = Paint()
      ..color = const Color(0xff146b59)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = const Color(0xff146b59)
      ..style = PaintingStyle.fill;

    final dotInnerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // 1. 다각형 보조격자선 (20%, 40%, 60%, 80%, 100% 점수 레벨)
    const levels = [0.2, 0.4, 0.6, 0.8, 1.0];
    for (final level in levels) {
      final levelPath = Path();
      for (int i = 0; i < count; i++) {
        final angle = -math.pi / 2 + (2 * math.pi * i / count);
        final x = center.dx + radius * level * math.cos(angle);
        final y = center.dy + radius * level * math.sin(angle);
        if (i == 0) {
          levelPath.moveTo(x, y);
        } else {
          levelPath.lineTo(x, y);
        }
      }
      levelPath.close();
      canvas.drawPath(levelPath, gridPaint);
    }

    // 2. 중심점에서 각 축 정점으로 방사선 그리기
    for (int i = 0; i < count; i++) {
      final angle = -math.pi / 2 + (2 * math.pi * i / count);
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      canvas.drawLine(center, Offset(x, y), axisLinePaint);
    }

    // 3. 실제 유저 평균 점수 다각형 면적 및 외곽선 렌더링
    final dataPoints = <Offset>[];
    for (int i = 0; i < count; i++) {
      final score = entries[i].value;
      final ratio = (score / 100.0).clamp(0.0, 1.0);
      final angle = -math.pi / 2 + (2 * math.pi * i / count);
      final x = center.dx + radius * ratio * math.cos(angle);
      final y = center.dy + radius * ratio * math.sin(angle);
      dataPoints.add(Offset(x, y));
    }

    if (dataPoints.isNotEmpty) {
      final dataPath = Path()..moveTo(dataPoints.first.dx, dataPoints.first.dy);
      for (int i = 1; i < dataPoints.length; i++) {
        dataPath.lineTo(dataPoints[i].dx, dataPoints[i].dy);
      }
      dataPath.close();

      canvas.drawPath(dataPath, dataFillPaint);
      canvas.drawPath(dataPath, dataStrokePaint);
    }

    // 4. 노드 점 및 정점 타이틀/점수 라벨 렌더링
    for (int i = 0; i < count; i++) {
      final p = dataPoints[i];
      final title = entries[i].key;
      final score = entries[i].value;

      canvas.drawCircle(p, 5.0, dotPaint);
      canvas.drawCircle(p, 2.0, dotInnerPaint);

      final angle = -math.pi / 2 + (2 * math.pi * i / count);
      final labelRadius = radius + 22.0;
      final lx = center.dx + labelRadius * math.cos(angle);
      final ly = center.dy + labelRadius * math.sin(angle);

      final shortTitle = title.length > 7 ? '${title.substring(0, 6)}…' : title;
      final textSpan = TextSpan(
        children: [
          TextSpan(text: '$shortTitle\n', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.black87)),
          TextSpan(
            text: score > 0 ? '${score.toStringAsFixed(1)}점' : '미수행',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: score > 0 ? const Color(0xff146b59) : Colors.grey,
            ),
          ),
        ],
      );

      final tp = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      tp.layout();

      canvas.save();
      tp.paint(canvas, Offset(lx - tp.width / 2, ly - tp.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _RadarChartPainter oldDelegate) => oldDelegate.scores != scores;
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.show_chart_rounded, color: Color(0xff146b59), size: 22),
                    SizedBox(width: 8),
                    Text('회차별 점수 변화 그래프', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xff146b59).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '평균 ${avgScore.toStringAsFixed(1)}점',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xff146b59)),
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
