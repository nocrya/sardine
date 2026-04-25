import 'package:dio/dio.dart';
import 'package:sardine/core/di/dependency_injection.dart';
import 'package:sardine/features/auth/data/auth_remote_datasource.dart';
import 'package:sardine/features/direct_message/data/direct_message_models.dart';

class DirectMessageRemoteDataSource {
  DirectMessageRemoteDataSource([
    Dio? client,
    AuthRemoteDataSource? authRemoteDataSource,
  ])  : _dio = client ?? getIt<Dio>(),
        _auth = authRemoteDataSource ?? getIt<AuthRemoteDataSource>();

  final Dio _dio;
  final AuthRemoteDataSource _auth;

  Future<List<DirectConversation>> listConversations() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/direct-conversations',
      options: _authorizedOptions(),
    );
    final data = response.data!['conversations'] as List<dynamic>? ?? [];
    return data
        .map(
            (item) => DirectConversation.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<int> createConversation(int peerUserId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/direct-conversations',
      data: {'peer_user_id': peerUserId},
      options: _authorizedOptions(),
    );
    return response.data!['conversation_id'] as int;
  }

  Future<List<DirectMessage>> listMessages(
    int conversationId, {
    int limit = 50,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/direct-conversations/$conversationId/messages',
      queryParameters: {'limit': limit},
      options: _authorizedOptions(),
    );
    final data = response.data!['messages'] as List<dynamic>? ?? [];
    return data
        .map((item) => DirectMessage.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<DirectMessage> createMessage({
    required int conversationId,
    required String content,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/direct-conversations/$conversationId/messages',
      data: {'content': content},
      options: _authorizedOptions(),
    );
    return DirectMessage.fromJson(
      response.data!['message'] as Map<String, dynamic>,
    );
  }

  Options _authorizedOptions() {
    final session = _auth.loadSession();
    final token = session?.accessToken ?? '';
    return Options(headers: {'Authorization': 'Bearer $token'});
  }
}
