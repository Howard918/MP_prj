import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../views/login_view.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class ServerConnectionHandler {
  static bool _isShowingDialog = false;
  static bool _isVerifying = false;

  // 💡 isSessionRevoked 플래그를 추가하여 명시적인 세션 강제 해제(409 중복 로그인 등)일 경우 서버 재검증을 우회하고 즉시 알림 팝업!
  static void handleDisconnection([String? customMessage, bool isSessionRevoked = false]) async {
    if (_isShowingDialog || _isVerifying) return;

    final context = navigatorKey.currentContext;
    if (context == null) {
      return;
    }

    if (!isSessionRevoked) {
      _isVerifying = true;
      // 💡 백그라운드 복귀 시 소켓 일시정지로 인한 가짜 연결 끊김 감지 방지
      // 실제로 서버가 꺼졌는지 1~1.5초 간격으로 최대 3회 재검증
      bool reallyDisconnected = true;
      for (int retry = 0; retry < 3; retry++) {
        await Future.delayed(Duration(milliseconds: retry == 0 ? 800 : 1500));
        final isAlive = await _checkServerAliveDirect();
        if (isAlive) {
          reallyDisconnected = false; // 실제로 서버가 가동 중이므로 연결 유지!
          break;
        }
      }

      _isVerifying = false;

      // 실제로 서버가 동작 중이거나 위젯 컨텍스트가 이탈했다면 알림을 발생시키지 않고 세션 유지
      if (!reallyDisconnected || !context.mounted) return;
    }

    _isShowingDialog = true;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false, // 🛑 뒤로가기 제스처/버튼 완전 차단
        child: AlertDialog(
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

  static Future<bool> _checkServerAliveDirect([String? baseUrl]) async {
    try {
      final targetUrl = (baseUrl != null && baseUrl.isNotEmpty) ? baseUrl : 'http://10.0.2.2:8000';
      final response = await http.get(Uri.parse('$targetUrl/')).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) return true;
    } catch (_) {}
    return false;
  }
}
