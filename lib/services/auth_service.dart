import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/practice_report.dart';
import '../utils/server_connection_handler.dart';
import '../config/api_config.dart';
import 'data_service.dart';
import 'package:uuid/uuid.dart';

final authServiceProvider = ChangeNotifierProvider<AuthService>((ref) => AuthService());

class LoginResult {
  final bool success;
  final String? errorMessage;
  final bool isConflict;

  LoginResult({required this.success, this.errorMessage, this.isConflict = false});
}

class RegisterResult {
  final bool success;
  final String? errorMessage;

  RegisterResult({required this.success, this.errorMessage});
}

class AuthService extends ChangeNotifier with WidgetsBindingObserver {
  UserModel? currentUser;
  String? accessToken;

  Timer? _heartbeatTimer;

  String? _customBaseUrl;
  static const String _tokenKey = 'jwt_access_token';
  static const String _savedUserKey = 'saved_user_id';
  static const String _customUrlKey = 'custom_backend_url';
  
  // 기기 식별을 위한 고유 Device ID 캐시
  String? _deviceId;

  AuthService() {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    stopHeartbeatCheck();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 💡 백그라운드 복귀 감지 시 세션 정황 1회 즉시 검증
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && currentUser != null && accessToken != null) {
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (currentUser != null && accessToken != null) {
          _checkHeartbeat();
        }
      });
    }
  }

  // 🔴 경량 기기 세션 헬스체크 (1초 주기로 빠른 수신 -> 기존 기기 1초 만에 즉시 알림 팝업 수신 보장)
  void startHeartbeatCheck() {
    stopHeartbeatCheck();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (currentUser == null || accessToken == null) {
        stopHeartbeatCheck();
        return;
      }
      await _checkHeartbeat();
    });
  }

  void stopHeartbeatCheck() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  // 💡 경량 하트비트: 데이터 패치 없이 세션 무효화(409) / 토큰 만료(401)만 체킹
  Future<void> _checkHeartbeat() async {
    if (currentUser == null || accessToken == null) return;
    try {
      final deviceId = await getDeviceId();
      final response = await http.get(
        Uri.parse('$baseUrl/users/me?device_id=$deviceId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final userData = jsonDecode(utf8.decode(response.bodyBytes));
        currentUser = UserModel.fromJson(userData);
        notifyListeners();
      } else if (response.statusCode == 409 && currentUser != null) {
        // 🔒 다른 기기에서 중복 로그인 감지 시 기존 기기 세션 즉시 해제! (isSessionRevoked 플래그 true 전달)
        stopHeartbeatCheck();
        ServerConnectionHandler.handleDisconnection('다른 기기에서 동일한 계정으로 새로 로그인되었습니다.\n현재 기기에서의 접속이 해제됩니다.', true);
      } else if (response.statusCode == 401 && currentUser != null) {
        stopHeartbeatCheck();
        ServerConnectionHandler.handleDisconnection('인증 세션이 만료되었습니다.\n다시 로그인해 주세요.', true);
      }
    } catch (e) {
      // 소켓 연결 지연이나 일시적 네트워크 예외 시 무음 처리 (가짜 연결 끊김 팝업 방지)
      debugPrint('하트비트 통신 예외 무음 처리: $e');
    }
  }

  // 기존 startHealthCheck/stopHealthCheck 인터페이스 호환 보장
  void startHealthCheck([DataService? dataService]) => startHeartbeatCheck();

  Future<void> initServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    _customBaseUrl = prefs.getString(_customUrlKey);
  }

  // 기기 고유 ID 생성 또는 조회 (앱 재설치 전까지 유지)
  Future<String> getDeviceId() async {
    if (_deviceId != null && _deviceId!.isNotEmpty) return _deviceId!;
    final prefs = await SharedPreferences.getInstance();
    String? storedId = prefs.getString('device_unique_id');
    if (storedId == null || storedId.isEmpty) {
      storedId = const Uuid().v4();
      await prefs.setString('device_unique_id', storedId);
    }
    _deviceId = storedId;
    return _deviceId!;
  }

  // FastAPI 백엔드 서버 주소 (커스텀 설정 우선 적용, 자동 감지 IP 우선, 에뮬레이터 루프백 기본)
  String get baseUrl {
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      return _customBaseUrl!;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      if (ApiConfig.backendUrl.contains('127.0.0.1')) {
        return 'http://10.0.2.2:8000'; // 안드로이드 에뮬레이터 기본 주소
      }
    }
    return ApiConfig.backendUrl; // 자동 감지된 백엔드 IP 주소
  }

  Future<void> updateCustomBaseUrl(String newUrl) async {
    final cleanUrl = newUrl.trim();
    _customBaseUrl = cleanUrl;
    final prefs = await SharedPreferences.getInstance();
    if (cleanUrl.isNotEmpty) {
      await prefs.setString(_customUrlKey, cleanUrl);
    } else {
      await prefs.remove(_customUrlKey);
    }
    notifyListeners();
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

  // 1. 자동 로그인 시도 (단일 계정 격리 보장)
  Future<bool> tryAutoLogin([DataService? dataService]) async {
    stopHeartbeatCheck();
    dataService?.clearUserData(); // 이전 계정 데이터 메모리 세척

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);

    if (token != null && token.isNotEmpty) {
      accessToken = token;
      final profileSuccess = await _fetchUserProfileFromBackend(token);
      if (profileSuccess) {
        startHeartbeatCheck(); // 경량 세션 체킹 시동
        return true;
      }
    }

    currentUser = null;
    accessToken = null;
    return false;
  }

  // 2. 로그인 (한 기기 당 한 계정 작동 단일 세션 보장)
  Future<LoginResult> login(String id, String password, {bool force = false, DataService? dataService}) async {
    try {
      stopHeartbeatCheck();
      currentUser = null;
      accessToken = null;
      dataService?.clearUserData(); // 💡 유저 전환 시 이전 유저 데이터 전체 메모리 소멸

      final deviceId = await getDeviceId();
      
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': id,
          'password': password,
          'device_id': deviceId,
          'force': force,
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
          startHeartbeatCheck(); // 경량 세션 체킹 시동
          return LoginResult(success: true);
        } else {
          return LoginResult(
            success: false,
            errorMessage: '유저 프로필 정보를 불러올 수 없습니다.',
          );
        }
      } else if (response.statusCode == 202) {
        // 💡 기존 기기에 해제 알림 신호 전송 완료 -> 기존 기기 1초 헬스체크에서 알림을 수신 및 세션 해제할 때까지 최대 10초간 1초 간격 재시도
        for (int retry = 0; retry < 10; retry++) {
          await Future.delayed(const Duration(seconds: 1));
          final retryRes = await http.post(
            Uri.parse('$baseUrl/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': id,
              'password': password,
              'device_id': deviceId,
              'force': true,
            }),
          ).timeout(const Duration(seconds: 4));

          if (retryRes.statusCode == 200) {
            final data = jsonDecode(utf8.decode(retryRes.bodyBytes));
            accessToken = data['access_token'];
            
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_tokenKey, accessToken!);
            await prefs.setString(_savedUserKey, id);

            final profileSuccess = await _fetchUserProfileFromBackend(accessToken!);
            if (profileSuccess) {
              startHeartbeatCheck(); // 경량 세션 체킹 시동
              return LoginResult(success: true);
            }
          }
        }
        return LoginResult(
          success: false,
          errorMessage: '기존 기기에서의 로그아웃 수신 처리가 지연되고 있습니다. 다시 시도해 주세요.',
        );
      } else if (response.statusCode == 409) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return LoginResult(
          success: false,
          isConflict: true,
          errorMessage: data['detail'] ?? '다른 기기에서 이미 로그인되어 있습니다.',
        );
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

  // 4. 백엔드 GET /users/me 엔드포인트 호출 (기기 중복 검증 포함)
  Future<bool> _fetchUserProfileFromBackend(String token) async {
    try {
      final deviceId = await getDeviceId();
      
      final response = await http.get(
        Uri.parse('$baseUrl/users/me?device_id=$deviceId'),
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
      } else if (response.statusCode == 409 && currentUser != null) {
        stopHeartbeatCheck();
        ServerConnectionHandler.handleDisconnection('다른 기기에서 동일한 계정으로 새로 로그인되었습니다.\n현재 기기에서의 접속이 해제됩니다.');
      } else if (response.statusCode == 401 && currentUser != null) {
        stopHeartbeatCheck();
        ServerConnectionHandler.handleDisconnection('인증 세션이 만료되었습니다.\n다시 로그인해 주세요.');
      }
    } catch (e) {
      debugPrint('FastAPI 프로필 정보 수신 실패: $e');
    }
    return false;
  }

  // 4-1. 외부에서 수동으로 현재 유저 프로필 강제 최신화 호출
  Future<bool> reloadUserProfile() async {
    if (accessToken == null) return false;
    return await _fetchUserProfileFromBackend(accessToken!);
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
        stopHeartbeatCheck();
        ServerConnectionHandler.handleDisconnection('관리자 인증 세션이 만료되었습니다.\n다시 로그인해 주세요.');
      }
    } catch (e) {
      debugPrint('관리자 전체 유저 조회 실패: $e');
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
        stopHeartbeatCheck();
        ServerConnectionHandler.handleDisconnection('관리자 인증 세션이 만료되었습니다.\n다시 로그인해 주세요.');
      }
    } catch (e) {
      debugPrint('관리자 유저 리포트 조회 실패: $e');
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
    }
    return false;
  }

  // 9. 로그아웃 (서버 기기 세션 해제 및 상태 초기화)
  Future<void> logout([DataService? dataService]) async {
    stopHeartbeatCheck();

    // 백엔드 서버에 로그아웃 통보하여 DB 상의 current_device_id 세션 해제
    if (accessToken != null && accessToken!.isNotEmpty) {
      try {
        await http.post(
          Uri.parse('$baseUrl/auth/logout'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
        ).timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('서버 로그아웃 통신 실패: $e');
      }
    }

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
