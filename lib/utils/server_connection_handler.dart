import 'package:flutter/material.dart';
import '../views/login_view.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class ServerConnectionHandler {
  static bool _isShowingDialog = false;

  static void handleDisconnection([String? customMessage]) {
    if (_isShowingDialog) return;

    final context = navigatorKey.currentContext;
    if (context == null) return;

    _isShowingDialog = true;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.wifi_off_rounded, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text('서버 연결 끊김', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          customMessage ?? '백엔드 서버와의 연결이 끊어졌습니다.\n네트워크 상태 및 서버 작동을 확인한 후 다시 로그인해 주세요.',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xff146b59)),
            onPressed: () {
              _isShowingDialog = false;
              Navigator.pop(ctx);
              // 서버 끊김 이동 시 자동 로그인 검증 생략(skipAutoLogin: true) 적용
              navigatorKey.currentState?.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginView(skipAutoLogin: true)),
                (route) => false,
              );
            },
            child: const Text('확인 (로그인 화면으로 이동)'),
          ),
        ],
      ),
    );
  }
}
