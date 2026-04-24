import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sardine/core/di/dependency_injection.dart';
import 'package:sardine/features/auth/data/auth_session.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource([
    Dio? client,
    SharedPreferences? preferences,
  ])  : _dio = client ?? getIt<Dio>(),
        _preferences = preferences ?? getIt<SharedPreferences>();

  final Dio _dio;
  final SharedPreferences _preferences;
  static const _sessionKey = 'auth.session';

  Dio get client => _dio;

  Future<AuthSession> register({
    required String email,
    required String username,
    required String password,
    required String displayName,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/register',
      data: {
        'email': email,
        'username': username,
        'password': password,
        'display_name': displayName,
      },
    );
    final session = AuthSession.fromJson(response.data!);
    await saveSession(session);
    return session;
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/login',
      data: {'email': email, 'password': password},
    );
    final session = AuthSession.fromJson(response.data!);
    await saveSession(session);
    return session;
  }

  Future<AuthUser> me(String accessToken) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/me',
      options: Options(
        headers: {'Authorization': 'Bearer $accessToken'},
      ),
    );
    return AuthUser.fromJson(response.data!['user'] as Map<String, dynamic>);
  }

  AuthSession? loadSession() {
    final raw = _preferences.getString(_sessionKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveSession(AuthSession session) {
    return _preferences.setString(_sessionKey, jsonEncode(session.toJson()));
  }

  Future<void> clearSession() {
    return _preferences.remove(_sessionKey);
  }
}
