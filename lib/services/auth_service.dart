import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/user_model.dart';
import '../models/practice_report.dart';
import '../utils/server_connection_handler.dart';
import 'data_service.dart';

final authServiceProvider = ChangeNotifierProvider<AuthService>((ref) => AuthService());

class LoginResult {
  final bool success;
  final String? errorMessage;

  LoginResult({required this.success, this.errorMessage});
}

class RegisterResult {
  final bool success;
  final String? errorMessage;

  RegisterResult({required this.success, this.errorMessage});
}

class AuthService extends ChangeNotifier {
  UserModel? currentUser;
  String? accessToken;

  Timer? _healthTimer;

  static const String _tokenKey = 'jwt_access_token';
  static const String _savedUserKey = 'saved_user_id';

  // FastAPI 백엔드 서버 주소 (.env 선언 우선 적용, 안드로이드 에뮬레이터 루프백 기본 적용)
  String get baseUrl {
    final envUrl = dotenv.env['BACKEND_API_URL'];
    if (envUrl != null && envUrl.isNotEmpty) return envUrl;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000'; // 안드로이드 에뮬레이터 호스트 주소
    }
    return 'http://localhost:8000'; // iOS / Web / Desktop 호스트 주소
  }

  // 🔴 백엔드 서버 주기적 상태 헬스체크 (10초 주기로 자동 감지)
  void startHealthCheck() {
    stopHealthCheck();
    _healthTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (currentUser == null || accessToken == null) {
        stopHealthCheck();
        return;
      }
      final isAlive = await checkServerHealth();
      if (!isAlive && currentUser != null) {
        stopHealthCheck();
        ServerConnectionHandler.handleDisconnection('백엔드 서버와의 통신이 중단되었습니다.\n서버 작동 상태를 확인 후 다시 로그인해 주세요.');
      }
    });
  }

  void stopHealthCheck() {
    _healthTimer?.cancel();
    _healthTimer = null;
  }

  Future<bool> checkServerHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/'),
      ).timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // 1. 자동 로그인 시도 (서버 연결 및 JWT 토큰 검증 필수)
  Future<bool> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);

    if (token != null && token.isNotEmpty) {
      accessToken = token;
      final profileSuccess = await _fetchUserProfileFromBackend(token);
      if (profileSuccess) {
        startHealthCheck(); // 주기적 서버 헬스체크 시동
        return true;
      }
    }

    // 서버 미구동 또는 토큰 만료 시 자동 로그인 미허용
    currentUser = null;
    accessToken = null;
    return false;
  }

  // 2. 로그인 (FastAPI 서버 통신)
  Future<LoginResult> login(String id, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': id,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        accessToken = data['access_token'];
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, accessToken!);
        await prefs.setString(_savedUserKey, id);

        // 유저 프로필 정보 수신
        final profileSuccess = await _fetchUserProfileFromBackend(accessToken!);
        if (profileSuccess) {
          startHealthCheck(); // 주기적 서버 헬스체크 시동
          return LoginResult(success: true);
        } else {
          return LoginResult(
            success: false,
            errorMessage: '유저 프로필 정보를 불러올 수 없습니다.',
          );
        }
      } else if (response.statusCode == 401) {
        return LoginResult(
          success: false,
          errorMessage: '아이디 또는 비밀번호가 올바르지 않습니다.',
        );
      } else if (response.statusCode == 422) {
        return LoginResult(
          success: false,
          errorMessage: '로그인 파라미터 규격 오류입니다. (코드: 422)',
        );
      } else {
        return LoginResult(
          success: false,
          errorMessage: '서버 오류가 발생했습니다. (코드: ${response.statusCode})',
        );
      }
    } catch (e) {
      debugPrint('FastAPI 백엔드 서버 연결 실패: $e');
      return LoginResult(
        success: false,
        errorMessage: '백엔드 서버에 연결할 수 없습니다.\nFastAPI 서버($baseUrl)가 실행 중인지 확인해 주세요.',
      );
    }
  }

  // 3. 회원가입 (FastAPI POST /auth/register 통신)
  Future<RegisterResult> register({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'name': name,
          'role': role,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 201) {
        return RegisterResult(success: true);
      } else if (response.statusCode == 400) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return RegisterResult(
          success: false,
          errorMessage: data['detail'] ?? '이미 등록된 아이디 또는 이메일입니다.',
        );
      } else {
        return RegisterResult(
          success: false,
          errorMessage: '회원가입 중 오류가 발생했습니다. (코드: ${response.statusCode})',
        );
      }
    } catch (e) {
      debugPrint('FastAPI 회원가입 통신 실패: $e');
      return RegisterResult(
        success: false,
        errorMessage: '백엔드 서버에 연결할 수 없습니다.\nFastAPI 서버($baseUrl)가 실행 중인지 확인해 주세요.',
      );
    }
  }

  // 4. 백엔드 GET /users/me 엔드포인트 호출
  Future<bool> _fetchUserProfileFromBackend(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final userData = jsonDecode(utf8.decode(response.bodyBytes));
        currentUser = UserModel.fromJson(userData);
        notifyListeners();
        return true;
      } else if (response.statusCode == 401 && currentUser != null) {
        stopHealthCheck();
        ServerConnectionHandler.handleDisconnection('인증 세션이 만료되었습니다.\n다시 로그인해 주세요.');
      }
    } catch (e) {
      debugPrint('FastAPI 프로필 정보 수신 실패: $e');
      if (currentUser != null) {
        stopHealthCheck();
        ServerConnectionHandler.handleDisconnection();
      }
    }
    return false;
  }

  // [관리자 전용] 5. 전체 유저 목록 수신 API (GET /admin/users)
  Future<List<UserModel>> fetchAdminUsers() async {
    if (accessToken == null) return [];
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/users'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> usersJson = jsonDecode(utf8.decode(response.bodyBytes));
        return usersJson.map((j) => UserModel.fromJson(j)).toList();
      } else if (response.statusCode == 401 && currentUser != null) {
        stopHealthCheck();
        ServerConnectionHandler.handleDisconnection('관리자 인증 세션이 만료되었습니다.\n다시 로그인해 주세요.');
      }
    } catch (e) {
      debugPrint('관리자 전체 유저 조회 실패: $e');
      if (currentUser != null) {
        stopHealthCheck();
        ServerConnectionHandler.handleDisconnection();
      }
    }
    return [];
  }

  // [관리자 전용] 6. 특정 유저의 상황극 훈련 리포트 목록 수신 API (GET /admin/users/{user_id}/reports)
  Future<List<PracticeReport>> fetchAdminUserReports(int userId) async {
    if (accessToken == null) return [];
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/users/$userId/reports'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> reportsJson = jsonDecode(utf8.decode(response.bodyBytes));
        return reportsJson.map((j) => PracticeReport.fromJson(j)).toList();
      } else if (response.statusCode == 401 && currentUser != null) {
        stopHealthCheck();
        ServerConnectionHandler.handleDisconnection('관리자 인증 세션이 만료되었습니다.\n다시 로그인해 주세요.');
      }
    } catch (e) {
      debugPrint('관리자 유저 리포트 조회 실패: $e');
      if (currentUser != null) {
        stopHealthCheck();
        ServerConnectionHandler.handleDisconnection();
      }
    }
    return [];
  }

  // [관리자 전용] 7. 특정 유저 계정 삭제 API (DELETE /admin/users/{user_id})
  Future<bool> deleteAdminUser(int userId) async {
    if (accessToken == null) return false;
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/admin/users/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 204) {
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('관리자 유저 삭제 실패: $e');
      if (currentUser != null) {
        stopHealthCheck();
        ServerConnectionHandler.handleDisconnection();
      }
    }
    return false;
  }

  // [관리자 전용] 8. 유저 훈련 리포트에 관리자 피드백 코멘트 작성/수정 (PUT /admin/reports/{report_id}/comment)
  Future<bool> updateAdminReportComment(int reportId, String comment) async {
    if (accessToken == null) return false;
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/admin/reports/$reportId/comment'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'admin_comment': comment,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('관리자 리포트 코멘트 등록 실패: $e');
      if (currentUser != null) {
        stopHealthCheck();
        ServerConnectionHandler.handleDisconnection();
      }
    }
    return false;
  }

  // 9. 로그아웃 (이전 로그인 유저의 리포트 상태 및 헬스체크 타이머 초기화)
  void logout([DataService? dataService]) async {
    stopHealthCheck(); // 헬스체크 타이머 중단
    currentUser = null;
    accessToken = null;
    dataService?.clearUserData(); // 메모리 내 유저별 리포트 데이터 삭제
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_savedUserKey);
    notifyListeners();
  }

  bool get isLoggedIn => currentUser != null;
  bool get isAdmin => currentUser?.isAdmin ?? false;
}
