import 'package:flutter/material.dart';
import '../views/login_view.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class ServerConnectionHandler {
  static bool _isShowingDialog = false;

  static void handleDisconnection([String? customMessage, bool isSessionRevoked = false]) {
    if (_isShowingDialog) return;

    final context = navigatorKey.currentContext;
    if (context == null) return;

    _isShowingDialog = true;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false, // 🛑 뒤로가기 제스처 완전 차단
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.lock_reset_rounded, color: Colors.orange, size: 24),
              SizedBox(width: 8),
              Text('접속 세션 해제 안내', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Text(
            customMessage ?? '다른 기기에서 동일한 계정으로 새로 로그인되었습니다.\n현재 기기에서의 접속이 해제됩니다.',
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xff146b59)),
              onPressed: () {
                _isShowingDialog = false;
                Navigator.pop(ctx);
                navigatorKey.currentState?.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginView(skipAutoLogin: true)),
                  (route) => false,
                );
              },
              child: const Text('확인 (로그인 화면으로 이동)'),
            ),
          ],
        ),
      ),
    );
  }
}
