import 'package:dio/dio.dart';
import 'package:sardine/core/di/dependency_injection.dart';
import 'package:sardine/features/auth/data/auth_remote_datasource.dart';
import 'package:sardine/features/voice/data/voice_session_data.dart';

class VoiceRemoteDataSource {
  VoiceRemoteDataSource([
    Dio? client,
    AuthRemoteDataSource? authRemoteDataSource,
  ])  : _dio = client ?? getIt<Dio>(),
        _auth = authRemoteDataSource ?? getIt<AuthRemoteDataSource>();

  final Dio _dio;
  final AuthRemoteDataSource _auth;

  Future<VoiceSessionData> joinVoiceChannel(int channelId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/channels/$channelId/voice/join',
      options: _authorizedOptions(),
    );
    return VoiceSessionData.fromJson(
      response.data!['session'] as Map<String, dynamic>,
    );
  }

  Options _authorizedOptions() {
    final session = _auth.loadSession();
    final token = session?.accessToken ?? '';
    return Options(headers: {'Authorization': 'Bearer $token'});
  }
}
