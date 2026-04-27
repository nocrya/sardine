import 'package:dio/dio.dart';
import 'package:sardine/core/di/dependency_injection.dart';
import 'package:sardine/features/auth/data/auth_remote_datasource.dart';
import 'package:sardine/features/invite/data/invite_models.dart';
import 'package:sardine/features/server/data/server_models.dart';

class ServerRemoteDataSource {
  ServerRemoteDataSource([
    Dio? client,
    AuthRemoteDataSource? authRemoteDataSource,
  ])  : _dio = client ?? getIt<Dio>(),
        _auth = authRemoteDataSource ?? getIt<AuthRemoteDataSource>();

  final Dio _dio;
  final AuthRemoteDataSource _auth;

  Dio get client => _dio;

  Future<List<WorkspaceServer>> listServers() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/servers',
      options: _authorizedOptions(),
    );
    final data = response.data!['servers'] as List<dynamic>? ?? [];
    return data
        .map((item) => WorkspaceServer.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<WorkspaceChannel>> listChannels(int serverId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/servers/$serverId/channels',
      options: _authorizedOptions(),
    );
    final data = response.data!['channels'] as List<dynamic>? ?? [];
    return data
        .map((item) => WorkspaceChannel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<WorkspaceServerRoleMember>> listMembers(int serverId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/servers/$serverId/members',
      options: _authorizedOptions(),
    );
    final data = response.data!['members'] as List<dynamic>? ?? [];
    return data
        .map(
          (item) => WorkspaceServerRoleMember.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<WorkspaceMessagePage> listMessages(
    int channelId, {
    int limit = 30,
    int? beforeId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/channels/$channelId/messages',
      queryParameters: {
        'limit': limit,
        if (beforeId != null && beforeId > 0) 'before_id': beforeId,
      },
      options: _authorizedOptions(),
    );
    return WorkspaceMessagePage.fromJson(response.data!);
  }

  Future<void> createServer({
    required String name,
    String description = '',
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/api/v1/servers',
      data: {'name': name, 'description': description},
      options: _authorizedOptions(),
    );
  }

  Future<void> createChannel({
    required int serverId,
    required String name,
    String kind = 'text',
    String topic = '',
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/api/v1/servers/$serverId/channels',
      data: {'name': name, 'kind': kind, 'topic': topic},
      options: _authorizedOptions(),
    );
  }

  Future<List<WorkspaceServerRoleMember>> inviteMember({
    required int serverId,
    required String email,
    String role = 'member',
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/servers/$serverId/invites',
      data: {'email': email, 'role': role},
      options: _authorizedOptions(),
    );
    final data = response.data!['members'] as List<dynamic>? ?? [];
    return data
        .map(
          (item) => WorkspaceServerRoleMember.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<WorkspaceServerInvite> createInviteLink({
    required int serverId,
    String role = 'member',
    int maxUses = 0,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/servers/$serverId/invite-links',
      data: {'role': role, 'max_uses': maxUses},
      options: _authorizedOptions(),
    );
    return WorkspaceServerInvite.fromJson(
      response.data!['invite'] as Map<String, dynamic>,
    );
  }

  Future<void> joinByInviteCode(String code) async {
    await _dio.post<Map<String, dynamic>>(
      '/api/v1/invites/join',
      data: {'code': code},
      options: _authorizedOptions(),
    );
  }

  Future<InvitePreview> previewInvite(String code) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/invites/$code',
    );
    return InvitePreview.fromJson(
      response.data!['invite'] as Map<String, dynamic>,
    );
  }

  Future<List<WorkspaceServerRoleMember>> updateMemberRole({
    required int serverId,
    required int memberId,
    required String role,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/api/v1/servers/$serverId/members/$memberId',
      data: {'role': role},
      options: _authorizedOptions(),
    );
    final data = response.data!['members'] as List<dynamic>? ?? [];
    return data
        .map(
          (item) => WorkspaceServerRoleMember.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<void> leaveServer(int serverId) async {
    await _dio.post<Map<String, dynamic>>(
      '/api/v1/servers/$serverId/leave',
      options: _authorizedOptions(),
    );
  }

  Future<List<WorkspaceServerRoleMember>> removeMember({
    required int serverId,
    required int memberId,
  }) async {
    final response = await _dio.delete<Map<String, dynamic>>(
      '/api/v1/servers/$serverId/members/$memberId',
      options: _authorizedOptions(),
    );
    final data = response.data!['members'] as List<dynamic>? ?? [];
    return data
        .map(
          (item) => WorkspaceServerRoleMember.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<List<WorkspaceServerRoleMember>> transferOwnership({
    required int serverId,
    required int nextOwnerUserId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/servers/$serverId/transfer-ownership',
      data: {'next_owner_user_id': nextOwnerUserId},
      options: _authorizedOptions(),
    );
    final data = response.data!['members'] as List<dynamic>? ?? [];
    return data
        .map(
          (item) => WorkspaceServerRoleMember.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<WorkspaceMessage> sendMessage({
    required int channelId,
    required String content,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/channels/$channelId/messages',
      data: {'content': content},
      options: _authorizedOptions(),
    );
    return WorkspaceMessage.fromJson(
      response.data!['message'] as Map<String, dynamic>,
    );
  }

  Future<void> markChannelRead({
    required int channelId,
    required int messageId,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/api/v1/channels/$channelId/read',
      data: {'message_id': messageId},
      options: _authorizedOptions(),
    );
  }

  Options _authorizedOptions() {
    final session = _auth.loadSession();
    final token = session?.accessToken ?? '';
    return Options(headers: {'Authorization': 'Bearer $token'});
  }
}
