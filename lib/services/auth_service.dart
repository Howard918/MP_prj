import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../models/practice_report.dart';
import '../config/api_config.dart';
import '../utils/server_connection_handler.dart';
import 'data_service.dart';

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

class AuthService extends ChangeNotifier {
  UserModel? currentUser;
  String? accessToken;

  Timer? _heartbeatTimer;
  static const String _tokenKey = 'jwt_access_token';
  static const String _savedUserKey = 'saved_user_id';
  static const String _customUrlKey = 'custom_backend_url';

  String? _customBaseUrl;
  String? _deviceId;

  AuthService() {
    initServerUrl();
  }

  @override
  void dispose() {
    stopHeartbeatCheck();
    super.dispose();
  }

  String get baseUrl {
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      return _customBaseUrl!;
    }
    return ApiConfig.backendUrl;
  }

  Future<void> initServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    _customBaseUrl = prefs.getString(_customUrlKey);
  }

  Future<void> updateCustomBaseUrl(String newUrl) async {
    final cleanUrl = newUrl.trim();
    final prefs = await SharedPreferences.getInstance();
    if (cleanUrl.isNotEmpty && cleanUrl != ApiConfig.backendUrl) {
      _customBaseUrl = cleanUrl;
      await prefs.setString(_customUrlKey, cleanUrl);
    } else {
      _customBaseUrl = null;
      await prefs.remove(_customUrlKey);
    }
    notifyListeners();
  }

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

  // 🔴 4초 간격 백엔드 활성 하트비트 세션 점검 (서버 로그 GET /users/me 200 OK 지속 발송)
  void startHeartbeatCheck() {
    stopHeartbeatCheck();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (currentUser == null || accessToken == null) {
        stopHeartbeatCheck();
        return;
      }
      await reloadUserProfile();
    });
  }

  void stopHeartbeatCheck() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  // 1. 백엔드 실시간 프로필 패치 (GET /users/me - 기기 중복 검증 포함)
  Future<bool> reloadUserProfile([DataService? dataService]) async {
    if (accessToken == null || accessToken!.isEmpty) return false;
    try {
      final deviceId = await getDeviceId();
      final response = await http.get(
        Uri.parse('$baseUrl/users/me?device_id=$deviceId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final userData = jsonDecode(utf8.decode(response.bodyBytes));
        currentUser = UserModel.fromJson(userData);
        if (dataService != null) {
          dataService.syncUserNotifications(
            currentUser!.id,
            isAdmin: currentUser!.isAdmin,
            userDbId: currentUser!.dbId?.toString(),
          );
        }
        notifyListeners();
        return true;
      } else if (response.statusCode == 409 && currentUser != null) {
        // 🔒 다른 기기에서 중복 로그인 감지 시 기존 기기 세션 즉시 해제!
        stopHeartbeatCheck();
        final Map<String, dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        final msg = data['detail'] ?? '다른 기기에서 동일한 계정으로 새로 로그인되었습니다.\n현재 기기에서의 접속이 해제됩니다.';
        logout();
        ServerConnectionHandler.handleDisconnection(msg, true);
        return false;
      } else if (response.statusCode == 401 && currentUser != null) {
        stopHeartbeatCheck();
        logout();
        ServerConnectionHandler.handleDisconnection('인증 세션이 만료되었습니다.\n다시 로그인해 주세요.', true);
        return false;
      }
    } catch (e) {
      debugPrint('백엔드 프로필 정보 수신 예외: $e');
    }
    return false;
  }

  // 2. 자동 로그인 시도 (저장된 정식 JWT 토큰으로 백엔드 통신)
  Future<bool> tryAutoLogin([DataService? dataService]) async {
    stopHeartbeatCheck();
    dataService?.clearUserData();

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);

    if (token != null && token.isNotEmpty) {
      accessToken = token;
      final profileSuccess = await reloadUserProfile(dataService);
      if (profileSuccess) {
        startHeartbeatCheck();
        return true;
      }
    }

    currentUser = null;
    accessToken = null;
    return false;
  }

  // 3. 백엔드 서버 100% 정식 로그인 (POST /auth/login)
  Future<LoginResult> login(String id, String password, {bool force = false, DataService? dataService}) async {
    try {
      stopHeartbeatCheck();
      currentUser = null;
      accessToken = null;
      dataService?.clearUserData();

      final deviceId = await getDeviceId();

      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': id.trim(),
          'password': password.trim(),
          'device_id': deviceId,
          'force': force,
        }),
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        accessToken = data['access_token'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, accessToken!);
        await prefs.setString(_savedUserKey, id.trim());

        // 백엔드 DB에서 정식 프로필 수신
        final profileSuccess = await reloadUserProfile(dataService);
        if (profileSuccess) {
          startHeartbeatCheck();
          return LoginResult(success: true);
        } else {
          return LoginResult(
            success: false,
            errorMessage: '백엔드 DB에서 프로필 정보를 불러올 수 없습니다.',
          );
        }
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
      } else {
        return LoginResult(
          success: false,
          errorMessage: '서버 오류가 발생했습니다. (코드: ${response.statusCode})',
        );
      }
    } catch (e) {
      debugPrint('FastAPI 백엔드 서버 로그인 통신 실패: $e');
      return LoginResult(
        success: false,
        errorMessage: '백엔드 서버에 연결할 수 없습니다.\nFastAPI 서버($baseUrl)가 가동 중인지 확인해 주세요.',
      );
    }
  }

  // 4. 백엔드 서버 회원가입 (POST /auth/register)
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
          'email': email.trim(),
          'password': password.trim(),
          'name': name.trim(),
          'role': role,
        }),
      ).timeout(const Duration(seconds: 6));

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
          errorMessage: '회원가입 처리 중 오류가 발생했습니다. (코드: ${response.statusCode})',
        );
      }
    } catch (e) {
      debugPrint('FastAPI 회원가입 통신 실패: $e');
      return RegisterResult(
        success: false,
        errorMessage: '백엔드 서버 통신 오류가 발생했습니다.',
      );
    }
  }

  bool _isReportForUser(PracticeReport report, UserModel user) {
    final rUid = report.userId.trim();
    final dbIdStr = user.dbId?.toString() ?? '';
    final uId = user.id.trim();
    final uName = user.name.trim();

    if (rUid == dbIdStr || rUid == uId || rUid == uName) {
      return true;
    }
    if ((uId == 'user' || user.dbId == 1) && (rUid == '1' || rUid == 'user' || rUid.isEmpty)) {
      return true;
    }
    if ((uId == 'admin' || user.dbId == 2) && (rUid == '2' || rUid == 'admin')) {
      return true;
    }
    return false;
  }

  // [관리자 전용] 5. 전체 유저 목록 수신 API (GET /admin/users)
  Future<List<UserModel>> fetchAdminUsers([DataService? dataService]) async {
    if (accessToken == null || accessToken!.isEmpty) return [];
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
        final users = usersJson.map((j) => UserModel.fromJson(j)).toList();

        if (dataService != null) {
          await dataService.fetchReportsFromBackend(accessToken, baseUrl);

          final updatedUsers = <UserModel>[];
          for (final u in users) {
            final userReports = dataService.practiceReports.where(
              (r) => _isReportForUser(r, u)
            ).toList();

            final totalCount = userReports.length;
            final double avgScore = totalCount > 0
                ? (userReports.map((r) => r.score).reduce((a, b) => a + b) / totalCount)
                : u.averageScore;

            final weaknesses = userReports.isEmpty
                ? u.weaknessCategories
                : userReports
                    .where((r) => r.score < 80)
                    .map((r) => r.scenarioTitle)
                    .toSet()
                    .toList();

            updatedUsers.add(UserModel(
              dbId: u.dbId,
              id: u.id,
              password: u.password,
              name: u.name,
              role: u.role,
              totalSessions: totalCount > 0 ? totalCount : u.totalSessions,
              averageScore: double.parse((totalCount > 0 ? avgScore : u.averageScore).toStringAsFixed(1)),
              weaknessCategories: weaknesses,
            ));
          }
          return updatedUsers;
        }

        return users;
      }
    } catch (e) {
      debugPrint('관리자 유저 목록 백엔드 수신 실패: $e');
    }
    return [];
  }

  // [관리자 전용] 6. 특정 유저 훈련 리포트 목록 수신 API (GET /admin/users/{user_id}/reports)
  Future<List<PracticeReport>> fetchAdminUserReports(int userId, [DataService? dataService]) async {
    if (accessToken == null || accessToken!.isEmpty) return [];
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/users/$userId/reports'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        final serverReports = jsonList.map((j) => PracticeReport.fromJson(j)).toList();
        return serverReports;
      }
    } catch (e) {
      debugPrint('관리자 유저 리포트 백엔드 수신 실패: $e');
    }
    return [];
  }

  // [관리자 전용] 7. 특정 유저 계정 삭제 API (DELETE /admin/users/{user_id})
  Future<bool> deleteAdminUser(int userId) async {
    if (accessToken == null || accessToken!.isEmpty) return false;
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

  // [관리자 전용] 8. 유저 훈련 리포트 피드백 코멘트 작성/수정 (PUT /admin/reports/{report_id}/comment)
  Future<bool> updateAdminReportComment(int reportId, String comment) async {
    if (accessToken == null || accessToken!.isEmpty) return false;
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/admin/reports/$reportId/comment'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'admin_comment': comment.trim(),
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

  // [관리자 전용] 8-1. 유저의 특정 훈련 리포트 강제 삭제 (DELETE /admin/reports/{report_id})
  Future<bool> deleteAdminReport(int reportId) async {
    if (accessToken == null || accessToken!.isEmpty) return false;
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/admin/reports/$reportId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 204 || response.statusCode == 200) {
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('관리자 리포트 삭제 실패: $e');
    }
    return false;
  }

  // 9. 로그아웃 (서버 세션 해제 및 토큰 삭제)
  Future<void> logout([DataService? dataService]) async {
    stopHeartbeatCheck();
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
    dataService?.clearUserData();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_savedUserKey);
    notifyListeners();
  }

  bool get isLoggedIn => currentUser != null;
  bool get isAdmin => currentUser?.isAdmin ?? false;
}
