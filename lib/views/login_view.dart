import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import 'dashboard_view.dart';
import 'register_view.dart';

class LoginView extends ConsumerStatefulWidget {
  final bool skipAutoLogin; // 서버 끊김 이동 시 자동 로그인 확인 생략 옵션

  const LoginView({this.skipAutoLogin = false, super.key});

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> with SingleTickerProviderStateMixin {
  final idController = TextEditingController();
  final passwordController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _isCheckingAutoLogin = true;
  bool _isDisconnectingOtherDevice = false; // 기존 기기 접속 해제 알림 전송 및 대기 화면 플래그
  String? errorMessage;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();

    // 흔들리는 애니메이션 (Shake Animation) 설정
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -12.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -12.0, end: 12.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 12.0, end: -12.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -12.0, end: 12.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -12.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));

    // 첫 프레임 렌더링 후 자동 로그인 체크 실행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAutoLogin();
    });
  }

  @override
  void dispose() {
    idController.dispose();
    passwordController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  // 앱 실행 시 저장된 로그인 정보 확인 (자동 로그인)
  Future<void> _checkAutoLogin() async {
    if (widget.skipAutoLogin) {
      if (mounted) {
        setState(() {
          _isCheckingAutoLogin = false;
        });
      }
      return;
    }

    try {
      final authService = ref.read(authServiceProvider);
      final dataService = ref.read(dataServiceProvider);
      final loggedIn = await authService.tryAutoLogin(dataService);

      if (loggedIn && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const Dashboard()),
        );
        return;
      }
    } catch (e) {
      debugPrint('자동 로그인 확인 중 오류 발생: $e');
    } finally {
      // 자동 로그인에 실패하거나 에러 발생 시 반드시 로딩을 해제하고 로그인 폼 노출
      if (mounted) {
        setState(() {
          _isCheckingAutoLogin = false;
        });
      }
    }
  }

  Future<void> _performLogin(String id, String password, {bool force = false}) async {
    if (id.trim().isEmpty || password.trim().isEmpty) {
      setState(() {
        _isDisconnectingOtherDevice = false;
        errorMessage = '아이디와 비밀번호를 모두 입력해 주세요.';
      });
      _shakeController.forward(from: 0.0);
      return;
    }

    final authService = ref.read(authServiceProvider);
    final dataService = ref.read(dataServiceProvider);
    final result = await authService.login(id.trim(), password.trim(), force: force, dataService: dataService);

    if (!mounted) return;

    if (result.success) {
      setState(() {
        _isDisconnectingOtherDevice = false;
      });
      // 💡 기존 기기 해제 완수 확인 후 곧바로 대시보드로 수직 이동!
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const Dashboard()),
      );
    } else if (result.isConflict) {
      setState(() {
        _isDisconnectingOtherDevice = false;
      });
      // 🔒 다른 기기 로그인 감지 시 강제 로그아웃 확인 팝업 표시
      _showForceLoginDialog(id.trim(), password.trim(), result.errorMessage ?? '다른 기기에서 이미 로그인되어 있습니다.');
    } else {
      setState(() {
        _isDisconnectingOtherDevice = false;
        errorMessage = result.errorMessage;
      });
      _shakeController.forward(from: 0.0);
    }
  }

  void _showForceLoginDialog(String id, String password, String conflictMsg) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.phonelink_erase_rounded, color: Colors.orange, size: 24),
              SizedBox(width: 8),
              Text('중복 로그인 확인', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Text(
            conflictMsg,
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xff146b59)),
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _isDisconnectingOtherDevice = true; // 💡 대기 로딩 화면으로 즉시 전환
                });
                _performLogin(id, password, force: true);
              },
              child: const Text('기존 기기 로그아웃 후 로그인'),
            ),
          ],
        ),
      ),
    );
  }

  // ⚙️ 실기기/에뮬레이터 백엔드 서버 URL 설정 및 연결 테스트 다이얼로그
  void _showServerConfigDialog() {
    final authService = ref.read(authServiceProvider);
    final urlController = TextEditingController(text: authService.baseUrl);
    bool isTesting = false;
    String? testResult;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.settings_ethernet, color: Color(0xff146b59)),
              SizedBox(width: 8),
              Text('서버 연결 주소 설정', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('실기기 무선 연결 시 백엔드 IP 주소(예: http://192.168.x.x:8000)를 설정합니다.', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: '백엔드 서버 URL',
                  hintText: 'http://192.168.0.2:8000',
                  border: OutlineInputBorder(),
                ),
              ),
              if (testResult != null) ...[
                const SizedBox(height: 10),
                Text(
                  testResult!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: testResult!.contains('성공') ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                urlController.text = ApiConfig.backendUrl;
                await authService.updateCustomBaseUrl('');
                setDialogState(() {
                  testResult = '기본 Render 클라우드 주소로 초기화되었습니다.';
                });
              },
              child: const Text('기본값 리셋'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            OutlinedButton(
              onPressed: isTesting ? null : () async {
                setDialogState(() {
                  isTesting = true;
                  testResult = '연결 테스트 진행 중...';
                });
                final testUrl = urlController.text.trim();
                try {
                  final resp = await http.get(Uri.parse('$testUrl/')).timeout(const Duration(seconds: 4));
                  if (resp.statusCode == 200) {
                    setDialogState(() {
                      isTesting = false;
                      testResult = '연결 성공! 백엔드 서버가 활성화되어 있습니다.';
                    });
                  } else {
                    setDialogState(() {
                      isTesting = false;
                      testResult = '연결 실패 (응답 코드: ${resp.statusCode})';
                    });
                  }
                } catch (e) {
                  setDialogState(() {
                    isTesting = false;
                    testResult = '연결 실패: $e';
                  });
                }
              },
              child: const Text('연결 테스트'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xff146b59)),
              onPressed: () async {
                await authService.updateCustomBaseUrl(urlController.text.trim());
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('서버 연결 주소가 설정되었습니다: ${authService.baseUrl}')),
                  );
                }
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAutoLogin) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('로그인 정보 확인 중...', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    // 💡 기존 기기 해제 알림 전송 및 해제 완수 대기 전용 풀스크린 로딩 화면
    if (_isDisconnectingOtherDevice) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Color(0xff146b59)),
                SizedBox(height: 24),
                Text(
                  '기존 기기에 로그아웃 알림 전송 중...',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                SizedBox(height: 10),
                Text(
                  '기존 기기에서 로그아웃 알림을 수신하여 세션을 해제하고 있습니다.\n해제가 완수되는 즉시 이 기기에서 로그인이 최종 허용됩니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, color: Colors.grey, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: AnimatedBuilder(
            animation: _shakeAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_shakeAnimation.value, 0),
                child: child,
              );
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                const Center(
                  child: Icon(
                    Icons.note_alt_rounded,
                    size: 64,
                    color: Color(0xff146b59),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  ApiConfig.appTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff146b59),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '알바 초보생을 위한 AI 맞춤 상황극 훈련 서비스',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 40),

                if (errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      errorMessage!,
                      style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                TextField(
                  controller: idController,
                  decoration: const InputDecoration(
                    labelText: '아이디 (이메일)',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: '비밀번호',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _performLogin(idController.text, passwordController.text),
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: () => _performLogin(idController.text, passwordController.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff146b59),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    '로그인',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),

                // 🚀 테스트 전용 빠른 로그인 버튼 (수습생 유저 / 점주 관리자)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Color(0xff146b59)),
                        ),
                        onPressed: () {
                          idController.text = 'user';
                          passwordController.text = 'user123';
                          _performLogin('user', 'user123');
                        },
                        icon: const Icon(Icons.person_outline, size: 18, color: Color(0xff146b59)),
                        label: const Text('유저 테스트 로그인', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xff146b59))),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Color(0xff146b59)),
                        ),
                        onPressed: () {
                          idController.text = 'admin';
                          passwordController.text = 'admin123';
                          _performLogin('admin', 'admin123');
                        },
                        icon: const Icon(Icons.admin_panel_settings_outlined, size: 18, color: Color(0xff146b59)),
                        label: const Text('점주 테스트 로그인', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xff146b59))),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('계정이 없으신가요?'),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RegisterView()),
                        );
                      },
                      child: const Text(
                        '회원가입',
                        style: TextStyle(
                          color: Color(0xff146b59),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Center(
                  child: TextButton.icon(
                    onPressed: _showServerConfigDialog,
                    icon: const Icon(Icons.settings_ethernet, size: 16, color: Colors.grey),
                    label: const Text(
                      '백엔드 서버 IP 주소 설정',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
