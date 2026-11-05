import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodels/chat_viewmodel.dart';

class ResultView extends ConsumerWidget {
  const ResultView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.read(chatViewModelProvider).evaluationResult;

    Color scoreColor = Colors.orange;
    if (result != null) {
      if (result.score >= 90) scoreColor = Colors.green;
      else if (result.score < 70) scoreColor = Colors.red;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('평가 결과'), automaticallyImplyLeading: false),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('상황극 대처 점수', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text(
                '${result?.score ?? 0} 점',
                style: TextStyle(fontSize: 60, fontWeight: FontWeight.bold, color: scoreColor),
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!)
                ),
                child: Text(
                  result?.feedback ?? '',
                  style: const TextStyle(fontSize: 16, height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 50),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                    child: const Text('홈으로 돌아가기'),
                  ),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // 이전 화면(Session Setup)으로 돌아가기
                    },
                    child: const Text('다시 연습하기'),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
