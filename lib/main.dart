import 'package:flutter/material.dart';

void main() => runApp(const FirstShiftApp());

class FirstShiftApp extends StatelessWidget {
  const FirstShiftApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '첫 근무 노트',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff146b59)),
      scaffoldBackgroundColor: const Color(0xfff6f8f5),
      useMaterial3: true,
    ),
    home: const Dashboard(),
  );
}

const scenarios = ['재료 소진', '주문 변경', '마감 직전 요청'];
const customerLines = [
  '주문한 음료의 재료가 없다면 어떤 메뉴로 바꿀 수 있나요?',
  '방금 주문한 음료를 다른 메뉴로 바꿀 수 있나요?',
  '마감 직전인데 포장 주문이 가능할까요?',
];

Widget content(List<Widget> children) => Align(
  alignment: Alignment.topCenter,
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 620),
    child: ListView(padding: const EdgeInsets.all(20), children: children),
  ),
);

Widget panel(
  String title,
  String description,
  IconData icon,
  VoidCallback onTap,
) => Card(
  clipBehavior: Clip.antiAlias,
  child: ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(description),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  ),
);

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int tab = 0;

  void open(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final pages = [
      [
        const Chip(label: Text('TEAM 5 · 화면 시안')),
        Text(
          '첫 근무를 연습해 보세요',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text('카페에서 만날 수 있는 상황으로 응대 순서를 익혀보세요.'),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () => setState(() => tab = 1),
          icon: const Icon(Icons.play_arrow),
          label: const Text('상황극 시작'),
        ),
        const SizedBox(height: 16),
        panel(
          '교육 리포트',
          '지난 연습 결과와 보완할 항목을 확인하세요.',
          Icons.insights,
          () => setState(() => tab = 2),
        ),
        panel(
          '매장 운영규칙',
          '매장 규칙과 현장 사례를 확인하세요.',
          Icons.storefront,
          () => setState(() => tab = 3),
        ),
      ],
      [
        const Text('연습할 상황을 선택하세요.'),
        for (var i = 0; i < scenarios.length; i++)
          panel(
            scenarios[i],
            customerLines[i],
            Icons.record_voice_over,
            () => open(Practice(index: i)),
          ),
      ],
      [
        const Chip(label: Text('예시 리포트')),
        panel(
          '최근 연습 · 재료 소진',
          '80점 · 대체 메뉴 안내 완료',
          Icons.assignment,
          () => open(const Result(index: 0)),
        ),
        panel(
          '보완할 항목',
          '환불 요청 시 관리자 확인 절차',
          Icons.flag,
          () => open(const Practice(index: 0)),
        ),
      ],
      [
        panel(
          '재료 소진 시 대응',
          '운영규칙 예시',
          Icons.menu_book,
          () => open(
            Scaffold(
              appBar: AppBar(title: const Text('운영규칙')),
              body: content([const Text('대체 메뉴를 안내합니다. 환불 요청 시 관리자에게 확인합니다.')]),
            ),
          ),
        ),
        panel(
          '현장 사례 등록',
          '상황과 대응을 작성하는 화면',
          Icons.note_add,
          () => open(const CaseForm()),
        ),
        panel(
          '검토 대기 사례',
          '예시 · 마감 직전 포장 주문 요청',
          Icons.fact_check,
          () => open(const ReviewCase()),
        ),
      ],
    ];
    return Scaffold(
      appBar: AppBar(title: Text(['첫 근무 노트', '상황극', '교육 리포트', '운영규칙'][tab])),
      body: content(pages[tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (index) => setState(() => tab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: '홈'),
          NavigationDestination(icon: Icon(Icons.chat_outlined), label: '상황극'),
          NavigationDestination(icon: Icon(Icons.insights), label: '리포트'),
          NavigationDestination(icon: Icon(Icons.storefront), label: '운영규칙'),
        ],
      ),
    );
  }
}

class Practice extends StatefulWidget {
  const Practice({required this.index, super.key});
  final int index;

  @override
  State<Practice> createState() => _PracticeState();
}

class _PracticeState extends State<Practice> {
  final input = TextEditingController();
  final replies = <String>[];
  bool voice = true;

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  void send(String reply) {
    setState(() {
      replies.add(reply);
      input.clear();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(scenarios[widget.index])),
    body: content([
      const Chip(label: Text('예시 상황극')),
      Card(
        child: ListTile(
          title: const Text('고객'),
          subtitle: Text(customerLines[widget.index]),
        ),
      ),
      for (final reply in replies) ...[
        Card(
          child: ListTile(title: const Text('나'), subtitle: Text(reply)),
        ),
        const Card(
          child: ListTile(
            title: Text('고객'),
            subtitle: Text('알겠습니다. 다음에는 어떻게 하면 될까요?'),
          ),
        ),
      ],
      const SizedBox(height: 12),
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(
            value: true,
            label: Text('음성'),
            icon: Icon(Icons.mic_none),
          ),
          ButtonSegment(
            value: false,
            label: Text('텍스트'),
            icon: Icon(Icons.keyboard),
          ),
        ],
        selected: {voice},
        onSelectionChanged: (value) => setState(() => voice = value.single),
      ),
      const SizedBox(height: 12),
      if (voice)
        OutlinedButton.icon(
          onPressed: () => send('확인 후 안내해 드리겠습니다.'),
          icon: const Icon(Icons.mic_none),
          label: const Text('음성 응답 예시 추가'),
        )
      else
        TextField(
          controller: input,
          onChanged: (_) => setState(() {}),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) send(value.trim());
          },
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: '응답 입력',
            suffixIcon: IconButton(
              tooltip: '전송',
              onPressed: input.text.trim().isEmpty
                  ? null
                  : () => send(input.text.trim()),
              icon: const Icon(Icons.send),
            ),
          ),
        ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: () => Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => Result(index: widget.index)),
        ),
        child: const Text('연습 종료 및 결과 보기'),
      ),
    ]),
  );
}

class Result extends StatelessWidget {
  const Result({required this.index, super.key});
  final int index;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('연습 결과')),
    body: content([
      const Chip(label: Text('예시 평가 · 실제 응답과 무관')),
      Text(scenarios[index], style: Theme.of(context).textTheme.headlineSmall),
      const Text(
        '80점',
        style: TextStyle(fontSize: 44, fontWeight: FontWeight.bold),
      ),
      const Card(
        child: ListTile(
          leading: Icon(Icons.check_circle_outline),
          title: Text('고객 요청 확인'),
        ),
      ),
      const Card(
        child: ListTile(
          leading: Icon(Icons.flag_outlined),
          title: Text('관리자 확인 절차 보완'),
        ),
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: () => Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => Practice(index: index)),
        ),
        child: const Text('다시 연습'),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('목록으로'),
      ),
    ]),
  );
}

class CaseForm extends StatelessWidget {
  const CaseForm({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('현장 사례 등록')),
    body: content([
      const TextField(
        decoration: InputDecoration(
          labelText: '상황 제목',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      const TextField(
        maxLines: 4,
        decoration: InputDecoration(
          labelText: '발생 상황과 대응 결과',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('제출 화면 미리보기'),
            content: const Text('이 시안에서는 입력한 사례가 저장되지 않습니다.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('확인'),
              ),
            ],
          ),
        ),
        child: const Text('검토 요청 미리보기'),
      ),
    ]),
  );
}

class ReviewCase extends StatelessWidget {
  const ReviewCase({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('사례 검토')),
    body: content([
      const Chip(label: Text('관리자 화면 예시')),
      Text('마감 직전 포장 주문 요청', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      const Text('기존 규칙에는 마감 직전 포장 주문의 접수 기준이 없습니다.'),
      const SizedBox(height: 12),
      const Card(
        child: ListTile(
          title: Text('보완안 예시'),
          subtitle: Text('마감 직전 접수 가능 여부를 담당 관리자에게 확인한다.'),
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 12,
        children: [
          for (final label in ['승인', '반려'])
            OutlinedButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$label 버튼 미리보기 · 규칙은 변경되지 않습니다.')),
              ),
              child: Text(label),
            ),
        ],
      ),
    ]),
  );
}
