import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
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
      final loggedIn = await authService.tryAutoLogin();

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

  Future<void> _performLogin(String id, String password) async {
    if (id.trim().isEmpty || password.trim().isEmpty) {
      setState(() {
        errorMessage = '아이디와 비밀번호를 모두 입력해 주세요.';
      });
      _shakeController.forward(from: 0.0);
      return;
    }

    final authService = ref.read(authServiceProvider);
    final result = await authService.login(id.trim(), password.trim());

    if (!mounted) return;

    if (result.success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const Dashboard()),
      );
    } else {
      setState(() {
        errorMessage = result.errorMessage;
      });
      _shakeController.forward(from: 0.0);
    }
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
                  final resp = await http.get(Uri.parse('$testUrl/')).timeout(const Duration(seconds: 3));
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

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.storefront_rounded, size: 64, color: Color(0xff146b59)),
                const SizedBox(height: 12),
                const Text(
                  '첫 근무 노트',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'AI 실전 상황극 훈련 서비스',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 36),

                // ID 입력창
                TextField(
                  controller: idController,
                  decoration: const InputDecoration(
                    labelText: '아이디',
                    hintText: '아이디를 입력하세요',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),

                // 보안 비밀번호 입력창 (보안 입력 & 가시성 토글 아이콘)
                TextField(
                  controller: passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: '비밀번호',
                    hintText: '비밀번호를 입력하세요',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _performLogin(idController.text, passwordController.text),
                ),

                // 실패 시 흔들리는 오류 알림 카드
                if (errorMessage != null) ...[
                  const SizedBox(height: 14),
                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(_shakeAnimation.value, 0),
                        child: child,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMessage!,
                              style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // 로그인 버튼
                ElevatedButton(
                  onPressed: () => _performLogin(idController.text, passwordController.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff146b59),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('로그인', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ),

                const SizedBox(height: 12),

                // 회원가입 페이지 이동 버튼
                TextButton(
                  onPressed: () async {
                    final registeredId = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterView()),
                    );
                    if (registeredId != null && registeredId.isNotEmpty) {
                      idController.text = registeredId;
                    }
                  },
                  child: const Text('아직 계정이 없으신가요? 회원가입하기'),
                ),

                const SizedBox(height: 8),

                // 서버 연결 설정 다이얼로그 버튼
                TextButton.icon(
                  onPressed: _showServerConfigDialog,
                  icon: const Icon(Icons.settings_ethernet, size: 18),
                  label: const Text('서버 연결 주소 설정 및 테스트', style: TextStyle(fontSize: 13, color: Colors.grey)),
                ),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),

                const Text(
                  '빠른 테스트 계정 로그인',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 12),

                // 원클릭 테스트 로그인 버튼
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _performLogin('user', 'user123'),
                        icon: const Icon(Icons.badge_outlined, size: 18),
                        label: const Text('일반 유저'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _performLogin('admin', 'admin123'),
                        icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
                        label: const Text('관리자'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
