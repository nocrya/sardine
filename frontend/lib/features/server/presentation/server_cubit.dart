import 'dart:async';

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sardine/features/auth/data/auth_remote_datasource.dart';
import 'package:sardine/features/auth/data/auth_session.dart';
import 'package:sardine/features/server/data/server_models.dart';
import 'package:sardine/features/server/data/server_remote_datasource.dart';
import 'package:sardine/features/server/data/workspace_realtime_service.dart';

class ServerViewState extends Equatable {
  const ServerViewState({
    this.loading = false,
    this.loadingOlderMessages = false,
    this.submittingMessage = false,
    this.submittingInvite = false,
    this.session,
    this.servers = const [],
    this.channels = const [],
    this.messages = const [],
    this.selectedServer,
    this.selectedChannel,
    this.errorMessage,
    this.hasMoreMessages = false,
    this.nextBeforeId = 0,
    this.messageFeedback,
    this.onlineMembers = const [],
    this.typingMembers = const [],
    this.serverMembers = const [],
    this.roleMembers = const [],
    this.latestInvite,
  });

  final bool loading;
  final bool loadingOlderMessages;
  final bool submittingMessage;
  final bool submittingInvite;
  final AuthSession? session;
  final List<WorkspaceServer> servers;
  final List<WorkspaceChannel> channels;
  final List<WorkspaceMessage> messages;
  final WorkspaceServer? selectedServer;
  final WorkspaceChannel? selectedChannel;
  final String? errorMessage;
  final bool hasMoreMessages;
  final int nextBeforeId;
  final String? messageFeedback;
  final List<WorkspaceMember> onlineMembers;
  final List<WorkspaceMember> typingMembers;
  final List<WorkspaceMember> serverMembers;
  final List<WorkspaceServerRoleMember> roleMembers;
  final WorkspaceServerInvite? latestInvite;

  bool get authenticated => session != null;
  bool get canManageChannels =>
      selectedServer?.memberRole == 'owner' ||
      selectedServer?.memberRole == 'admin';
  bool get canInviteMembers =>
      selectedServer?.memberRole == 'owner' ||
      selectedServer?.memberRole == 'admin';
  bool get canManageRoles => selectedServer?.memberRole == 'owner';
  bool get canTransferOwnership => selectedServer?.memberRole == 'owner';

  ServerViewState copyWith({
    bool? loading,
    bool? loadingOlderMessages,
    bool? submittingMessage,
    bool? submittingInvite,
    AuthSession? session,
    List<WorkspaceServer>? servers,
    List<WorkspaceChannel>? channels,
    List<WorkspaceMessage>? messages,
    WorkspaceServer? selectedServer,
    WorkspaceChannel? selectedChannel,
    String? errorMessage,
    bool? hasMoreMessages,
    int? nextBeforeId,
    String? messageFeedback,
    List<WorkspaceMember>? onlineMembers,
    List<WorkspaceMember>? typingMembers,
    List<WorkspaceMember>? serverMembers,
    List<WorkspaceServerRoleMember>? roleMembers,
    WorkspaceServerInvite? latestInvite,
    bool clearError = false,
    bool clearFeedback = false,
    bool clearInvite = false,
  }) {
    return ServerViewState(
      loading: loading ?? this.loading,
      loadingOlderMessages: loadingOlderMessages ?? this.loadingOlderMessages,
      submittingMessage: submittingMessage ?? this.submittingMessage,
      submittingInvite: submittingInvite ?? this.submittingInvite,
      session: session ?? this.session,
      servers: servers ?? this.servers,
      channels: channels ?? this.channels,
      messages: messages ?? this.messages,
      selectedServer: selectedServer ?? this.selectedServer,
      selectedChannel: selectedChannel ?? this.selectedChannel,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      hasMoreMessages: hasMoreMessages ?? this.hasMoreMessages,
      nextBeforeId: nextBeforeId ?? this.nextBeforeId,
      messageFeedback:
          clearFeedback ? null : messageFeedback ?? this.messageFeedback,
      onlineMembers: onlineMembers ?? this.onlineMembers,
      typingMembers: typingMembers ?? this.typingMembers,
      serverMembers: serverMembers ?? this.serverMembers,
      roleMembers: roleMembers ?? this.roleMembers,
      latestInvite: clearInvite ? null : latestInvite ?? this.latestInvite,
    );
  }

  @override
  List<Object?> get props => [
        loading,
        loadingOlderMessages,
        submittingMessage,
        submittingInvite,
        session,
        servers,
        channels,
        messages,
        selectedServer,
        selectedChannel,
        errorMessage,
        hasMoreMessages,
        nextBeforeId,
        messageFeedback,
        onlineMembers,
        typingMembers,
        serverMembers,
        roleMembers,
        latestInvite,
      ];
}

class ServerCubit extends Cubit<ServerViewState> {
  ServerCubit(
    this._serverDataSource,
    this._authDataSource,
    this._realtimeService,
  ) : super(
          ServerViewState(
            session: _authDataSource.loadSession(),
          ),
        ) {
    _realtimeSubscription =
        _realtimeService.events.listen(_handleRealtimeEvent);
  }

  final ServerRemoteDataSource _serverDataSource;
  final AuthRemoteDataSource _authDataSource;
  final WorkspaceRealtimeService _realtimeService;
  late final StreamSubscription<WorkspaceRealtimeEvent> _realtimeSubscription;
  static int _localMessageSeed = 0;

  Future<void> bootstrap() async {
    final session = _authDataSource.loadSession();
    if (session == null) {
      emit(const ServerViewState(errorMessage: 'Please sign in first.'));
      return;
    }

    emit(
      state.copyWith(
        loading: true,
        session: session,
        clearError: true,
        clearFeedback: true,
      ),
    );

    try {
      await _realtimeService.connect();
      final servers = await _serverDataSource.listServers();

      WorkspaceServer? selectedServer;
      WorkspaceChannel? selectedChannel;
      List<WorkspaceServerRoleMember> roleMembers = const [];
      List<WorkspaceChannel> channels = const [];
      List<WorkspaceMessage> messages = const [];
      var hasMoreMessages = false;
      var nextBeforeId = 0;

      if (servers.isNotEmpty) {
        selectedServer = servers.first;
        roleMembers = await _serverDataSource.listMembers(selectedServer.id);
        channels = await _serverDataSource.listChannels(selectedServer.id);
        _realtimeService.syncServerPresence(selectedServer.id);

        final firstTextChannel =
            channels.where((item) => item.isText).firstOrNull;
        if (firstTextChannel != null) {
          selectedChannel = firstTextChannel;
          final page =
              await _serverDataSource.listMessages(firstTextChannel.id);
          messages = page.messages;
          hasMoreMessages = page.hasMore;
          nextBeforeId = page.nextBeforeId;
          await _realtimeService.subscribeToChannel(firstTextChannel.id);
        }
      }

      emit(
        state.copyWith(
          loading: false,
          session: session,
          servers: servers,
          channels: channels,
          messages: messages,
          selectedServer: selectedServer,
          selectedChannel: selectedChannel,
          hasMoreMessages: hasMoreMessages,
          nextBeforeId: nextBeforeId,
          onlineMembers: const [],
          typingMembers: const [],
          serverMembers: const [],
          roleMembers: roleMembers,
          submittingInvite: false,
          clearInvite: true,
          clearError: true,
          clearFeedback: true,
        ),
      );
      await _markSelectedChannelRead();
    } on DioException catch (error) {
      emit(
        state.copyWith(
          loading: false,
          errorMessage: _messageFrom(error),
        ),
      );
    }
  }

  Future<void> createServer(String name) async {
    if (name.trim().isEmpty) return;

    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _serverDataSource.createServer(name: name.trim());
      await bootstrap();
    } on DioException catch (error) {
      emit(state.copyWith(loading: false, errorMessage: _messageFrom(error)));
    }
  }

  Future<void> createChannel(String name) async {
    final server = state.selectedServer;
    if (server == null || name.trim().isEmpty) return;

    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _serverDataSource.createChannel(
        serverId: server.id,
        name: name.trim(),
      );
      final channels = await _serverDataSource.listChannels(server.id);
      emit(state.copyWith(loading: false, channels: channels));
    } on DioException catch (error) {
      emit(state.copyWith(loading: false, errorMessage: _messageFrom(error)));
    }
  }

  Future<void> selectServer(WorkspaceServer server) async {
    emit(
      state.copyWith(
        loading: true,
        selectedServer: server,
        channels: const [],
        messages: const [],
        selectedChannel: null,
        hasMoreMessages: false,
        nextBeforeId: 0,
        onlineMembers: const [],
        typingMembers: const [],
        serverMembers: const [],
        roleMembers: const [],
        clearInvite: true,
        clearError: true,
        clearFeedback: true,
      ),
    );

    try {
      final channels = await _serverDataSource.listChannels(server.id);
      final roleMembers = await _serverDataSource.listMembers(server.id);
      _realtimeService.syncServerPresence(server.id);

      final textChannel = channels.where((item) => item.isText).firstOrNull;
      List<WorkspaceMessage> messages = const [];
      var hasMoreMessages = false;
      var nextBeforeId = 0;

      if (textChannel != null) {
        final page = await _serverDataSource.listMessages(textChannel.id);
        messages = page.messages;
        hasMoreMessages = page.hasMore;
        nextBeforeId = page.nextBeforeId;
        await _realtimeService.subscribeToChannel(textChannel.id);
      }

      emit(
        state.copyWith(
          loading: false,
          channels: channels,
          selectedChannel: textChannel,
          messages: messages,
          hasMoreMessages: hasMoreMessages,
          nextBeforeId: nextBeforeId,
          onlineMembers: const [],
          typingMembers: const [],
          serverMembers: const [],
          roleMembers: roleMembers,
          clearInvite: true,
        ),
      );
      await _markSelectedChannelRead();
    } on DioException catch (error) {
      emit(state.copyWith(loading: false, errorMessage: _messageFrom(error)));
    }
  }

  Future<void> selectChannel(WorkspaceChannel channel) async {
    emit(
      state.copyWith(
        loading: true,
        selectedChannel: channel,
        messages: const [],
        hasMoreMessages: false,
        nextBeforeId: 0,
        onlineMembers: const [],
        typingMembers: const [],
        clearInvite: true,
        clearError: true,
        clearFeedback: true,
      ),
    );

    try {
      final page = channel.isText
          ? await _serverDataSource.listMessages(channel.id)
          : const WorkspaceMessagePage(
              messages: [],
              hasMore: false,
              nextBeforeId: 0,
            );

      if (channel.isText) {
        await _realtimeService.subscribeToChannel(channel.id);
      }
      final server = state.selectedServer;
      if (server != null) {
        _realtimeService.syncServerPresence(server.id);
      }

      emit(
        state.copyWith(
          loading: false,
          messages: page.messages,
          hasMoreMessages: page.hasMore,
          nextBeforeId: page.nextBeforeId,
          onlineMembers: const [],
          typingMembers: const [],
        ),
      );
      await _markSelectedChannelRead();
    } on DioException catch (error) {
      emit(state.copyWith(loading: false, errorMessage: _messageFrom(error)));
    }
  }

  Future<void> loadOlderMessages() async {
    final channel = state.selectedChannel;
    if (channel == null ||
        !channel.isText ||
        state.loadingOlderMessages ||
        !state.hasMoreMessages ||
        state.nextBeforeId <= 0) {
      return;
    }

    emit(state.copyWith(loadingOlderMessages: true, clearFeedback: true));
    try {
      final page = await _serverDataSource.listMessages(
        channel.id,
        beforeId: state.nextBeforeId,
      );
      emit(
        state.copyWith(
          loadingOlderMessages: false,
          messages: [...page.messages, ...state.messages],
          hasMoreMessages: page.hasMore,
          nextBeforeId: page.nextBeforeId,
        ),
      );
    } on DioException catch (error) {
      emit(
        state.copyWith(
          loadingOlderMessages: false,
          messageFeedback: _messageFrom(error),
        ),
      );
    }
  }

  Future<void> sendMessage(String content) async {
    final channel = state.selectedChannel;
    if (channel == null || !channel.isText || content.trim().isEmpty) return;

    final clientId =
        'local-${DateTime.now().microsecondsSinceEpoch}-${_localMessageSeed++}';
    final localMessage = WorkspaceMessage(
      id: -1,
      channelId: channel.id,
      senderId: state.session?.user.id ?? 0,
      senderDisplayName: state.session?.user.displayName ?? 'You',
      content: content.trim(),
      createdAt: DateTime.now(),
      status: WorkspaceMessageStatus.sending,
      clientId: clientId,
    );

    emit(
      state.copyWith(
        submittingMessage: true,
        clearError: true,
        clearFeedback: true,
        messages: [...state.messages, localMessage],
      ),
    );

    try {
      final message = await _serverDataSource.sendMessage(
        channelId: channel.id,
        content: content.trim(),
      );
      final messages = state.messages
          .map(
            (item) => item.clientId == clientId
                ? message.copyWith(clientId: clientId)
                : item,
          )
          .toList();
      emit(
        state.copyWith(
          submittingMessage: false,
          messages: messages,
          clearFeedback: true,
        ),
      );
      await _markSelectedChannelRead();
    } on DioException catch (error) {
      final messages = state.messages
          .map(
            (item) => item.clientId == clientId
                ? item.copyWith(status: WorkspaceMessageStatus.failed)
                : item,
          )
          .toList();
      emit(
        state.copyWith(
          submittingMessage: false,
          messages: messages,
          messageFeedback: _messageFrom(error),
        ),
      );
    }
  }

  Future<void> retryMessage(String clientId) async {
    final message =
        state.messages.where((item) => item.clientId == clientId).firstOrNull;
    if (message == null) return;

    final remaining =
        state.messages.where((item) => item.clientId != clientId).toList();
    emit(
      state.copyWith(
        messages: remaining,
        clearFeedback: true,
      ),
    );
    await sendMessage(message.content);
  }

  Future<void> inviteMember({
    required String email,
    String role = 'member',
  }) async {
    final server = state.selectedServer;
    if (server == null || email.trim().isEmpty) return;

    emit(
      state.copyWith(
        submittingInvite: true,
        clearError: true,
        clearFeedback: true,
      ),
    );

    try {
      final members = await _serverDataSource.inviteMember(
        serverId: server.id,
        email: email.trim(),
        role: role,
      );
      emit(
        state.copyWith(
          submittingInvite: false,
          roleMembers: members,
          messageFeedback: 'Member invited',
        ),
      );
    } on DioException catch (error) {
      emit(
        state.copyWith(
          submittingInvite: false,
          messageFeedback: _messageFrom(error),
        ),
      );
    }
  }

  Future<void> createInviteLink({
    String role = 'member',
    int maxUses = 0,
  }) async {
    final server = state.selectedServer;
    if (server == null) return;

    emit(state.copyWith(loading: true, clearError: true, clearFeedback: true));
    try {
      final invite = await _serverDataSource.createInviteLink(
        serverId: server.id,
        role: role,
        maxUses: maxUses,
      );
      emit(
        state.copyWith(
          loading: false,
          latestInvite: invite,
          messageFeedback: 'Invite link created',
        ),
      );
    } on DioException catch (error) {
      emit(
        state.copyWith(
          loading: false,
          messageFeedback: _messageFrom(error),
        ),
      );
    }
  }

  Future<void> joinByInviteCode(String code) async {
    if (code.trim().isEmpty) return;

    emit(state.copyWith(loading: true, clearError: true, clearFeedback: true));
    try {
      await _serverDataSource.joinByInviteCode(code.trim());
      await bootstrap();
      emit(state.copyWith(messageFeedback: 'Joined server by invite'));
    } on DioException catch (error) {
      emit(
        state.copyWith(
          loading: false,
          messageFeedback: _messageFrom(error),
        ),
      );
    }
  }

  Future<void> updateMemberRole({
    required int memberId,
    required String role,
  }) async {
    final server = state.selectedServer;
    if (server == null) return;

    emit(state.copyWith(loading: true, clearError: true, clearFeedback: true));
    try {
      final members = await _serverDataSource.updateMemberRole(
        serverId: server.id,
        memberId: memberId,
        role: role,
      );

      final currentUserID = state.session?.user.id;
      final nextRole = currentUserID == memberId ? role : server.memberRole;
      final nextSelectedServer = WorkspaceServer(
        id: server.id,
        name: server.name,
        description: server.description,
        ownerId: server.ownerId,
        memberRole: nextRole,
        unreadCount: server.unreadCount,
      );
      final nextServers = state.servers
          .map((item) =>
              item.id == nextSelectedServer.id ? nextSelectedServer : item)
          .toList();

      emit(
        state.copyWith(
          loading: false,
          servers: nextServers,
          selectedServer: nextSelectedServer,
          roleMembers: members,
          messageFeedback: 'Member role updated',
        ),
      );
    } on DioException catch (error) {
      emit(
        state.copyWith(
          loading: false,
          messageFeedback: _messageFrom(error),
        ),
      );
    }
  }

  Future<void> leaveSelectedServer() async {
    final server = state.selectedServer;
    if (server == null) return;

    emit(state.copyWith(loading: true, clearError: true, clearFeedback: true));
    try {
      await _serverDataSource.leaveServer(server.id);
      await bootstrap();
      emit(state.copyWith(messageFeedback: 'Left server'));
    } on DioException catch (error) {
      emit(
        state.copyWith(
          loading: false,
          messageFeedback: _messageFrom(error),
        ),
      );
    }
  }

  Future<void> removeMember(int memberId) async {
    final server = state.selectedServer;
    if (server == null) return;

    emit(state.copyWith(loading: true, clearError: true, clearFeedback: true));
    try {
      final members = await _serverDataSource.removeMember(
        serverId: server.id,
        memberId: memberId,
      );
      emit(
        state.copyWith(
          loading: false,
          roleMembers: members,
          messageFeedback: 'Member removed',
        ),
      );
    } on DioException catch (error) {
      emit(
        state.copyWith(
          loading: false,
          messageFeedback: _messageFrom(error),
        ),
      );
    }
  }

  Future<void> transferOwnership(int nextOwnerUserId) async {
    final server = state.selectedServer;
    if (server == null) return;

    emit(state.copyWith(loading: true, clearError: true, clearFeedback: true));
    try {
      final members = await _serverDataSource.transferOwnership(
        serverId: server.id,
        nextOwnerUserId: nextOwnerUserId,
      );
      final currentUserId = state.session?.user.id;
      final nextRole = currentUserId == nextOwnerUserId ? 'owner' : 'admin';
      final updatedServer = WorkspaceServer(
        id: server.id,
        name: server.name,
        description: server.description,
        ownerId: nextOwnerUserId,
        memberRole: currentUserId == server.ownerId ? 'admin' : nextRole,
        unreadCount: server.unreadCount,
      );
      final servers = state.servers
          .map((item) => item.id == server.id ? updatedServer : item)
          .toList();
      emit(
        state.copyWith(
          loading: false,
          servers: servers,
          selectedServer: updatedServer,
          roleMembers: members,
          messageFeedback: 'Ownership transferred',
        ),
      );
    } on DioException catch (error) {
      emit(
        state.copyWith(
          loading: false,
          messageFeedback: _messageFrom(error),
        ),
      );
    }
  }

  Future<void> markChannelRead(int channelId, int messageId) {
    return _serverDataSource.markChannelRead(
      channelId: channelId,
      messageId: messageId,
    );
  }

  void clearMessageFeedback() {
    emit(state.copyWith(clearFeedback: true));
  }

  void typingChanged(String text) {
    final channel = state.selectedChannel;
    if (channel == null || !channel.isText) return;

    if (text.trim().isEmpty) {
      _realtimeService.sendTypingStop(channel.id);
      return;
    }
    _realtimeService.sendTypingStart(channel.id);
  }

  @override
  Future<void> close() async {
    await _realtimeSubscription.cancel();
    await _realtimeService.disconnect();
    return super.close();
  }

  String _messageFrom(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic> && data['error'] is String) {
      return data['error'] as String;
    }
    return error.message ?? 'Workspace request failed';
  }

  void _handleRealtimeEvent(WorkspaceRealtimeEvent event) {
    final payload = event.payload;

    switch (event.type) {
      case 'message.created':
        final channelId = payload['channel_id'] as int?;
        if (channelId == null || state.selectedChannel?.id != channelId) return;
        _handleRealtimeMessage(event);
        return;
      case 'presence.snapshot':
        final channelId = payload['channel_id'] as int?;
        if (channelId == null || state.selectedChannel?.id != channelId) return;
        final members = _membersFromList(payload['members']);
        emit(state.copyWith(
            onlineMembers: members.where((item) => item.online).toList()));
        return;
      case 'presence.joined':
        final channelId = payload['channel_id'] as int?;
        if (channelId == null || state.selectedChannel?.id != channelId) return;
        final member = _memberFromPayload(payload['member']);
        if (member == null ||
            state.onlineMembers.any((item) => item.userId == member.userId)) {
          return;
        }
        emit(state.copyWith(onlineMembers: [...state.onlineMembers, member]));
        return;
      case 'presence.left':
        final channelId = payload['channel_id'] as int?;
        if (channelId == null || state.selectedChannel?.id != channelId) return;
        final member = _memberFromPayload(payload['member']);
        if (member == null) return;
        emit(
          state.copyWith(
            onlineMembers: state.onlineMembers
                .where((item) => item.userId != member.userId)
                .toList(),
            typingMembers: state.typingMembers
                .where((item) => item.userId != member.userId)
                .toList(),
          ),
        );
        return;
      case 'server.presence.snapshot':
        final serverId = payload['server_id'] as int?;
        if (serverId == null || state.selectedServer?.id != serverId) return;
        emit(state.copyWith(
            serverMembers: _membersFromList(payload['members'])));
        return;
      case 'server.presence.updated':
        final serverId = payload['server_id'] as int?;
        if (serverId == null || state.selectedServer?.id != serverId) return;
        final member = _memberFromPayload(payload['member']);
        if (member == null) return;
        final updated = [...state.serverMembers];
        final index =
            updated.indexWhere((item) => item.userId == member.userId);
        if (index >= 0) {
          updated[index] = member;
        } else {
          updated.add(member);
        }
        emit(state.copyWith(serverMembers: updated));
        return;
      case 'typing.started':
        final channelId = payload['channel_id'] as int?;
        if (channelId == null || state.selectedChannel?.id != channelId) return;
        final member = _memberFromPayload(payload['member']);
        if (member == null || member.userId == state.session?.user.id) return;
        if (state.typingMembers.any((item) => item.userId == member.userId)) {
          return;
        }
        emit(state.copyWith(typingMembers: [...state.typingMembers, member]));
        return;
      case 'typing.stopped':
        final channelId = payload['channel_id'] as int?;
        if (channelId == null || state.selectedChannel?.id != channelId) return;
        final member = _memberFromPayload(payload['member']);
        if (member == null) return;
        emit(
          state.copyWith(
            typingMembers: state.typingMembers
                .where((item) => item.userId != member.userId)
                .toList(),
          ),
        );
        return;
    }
  }

  void _handleRealtimeMessage(WorkspaceRealtimeEvent event) {
    final messageJson = event.payload['message'] as Map<String, dynamic>?;
    if (messageJson == null) return;

    final message = WorkspaceMessage.fromJson(messageJson);
    if (state.messages.any((item) => item.id == message.id)) return;

    final localIndex = state.messages.indexWhere(
      (item) =>
          item.status == WorkspaceMessageStatus.sending &&
          item.senderId == message.senderId &&
          item.content == message.content,
    );

    if (localIndex >= 0) {
      final updated = [...state.messages];
      updated[localIndex] = message.copyWith(
        clientId: updated[localIndex].clientId,
      );
      emit(state.copyWith(messages: updated, submittingMessage: false));
      unawaited(_markSelectedChannelRead());
      return;
    }

    emit(state.copyWith(messages: [...state.messages, message]));
    unawaited(_markSelectedChannelRead());
  }

  Future<void> _markSelectedChannelRead() async {
    final channel = state.selectedChannel;
    if (channel == null || !channel.isText || state.messages.isEmpty) {
      return;
    }

    final latestMessageId = state.messages.last.id;
    if (latestMessageId <= 0) return;

    try {
      await markChannelRead(channel.id, latestMessageId);
      final updatedChannels = state.channels
          .map(
            (item) =>
                item.id == channel.id ? item.copyWith(unreadCount: 0) : item,
          )
          .toList();
      final nextUnread = updatedChannels.fold<int>(
        0,
        (sum, item) => sum + item.unreadCount,
      );
      final updatedServer =
          state.selectedServer?.copyWith(unreadCount: nextUnread);
      final updatedServers = state.servers
          .map(
            (item) => updatedServer != null && item.id == updatedServer.id
                ? updatedServer
                : item,
          )
          .toList();
      emit(
        state.copyWith(
          channels: updatedChannels,
          selectedServer: updatedServer,
          servers: updatedServers,
        ),
      );
    } on DioException {
      // ignore unread sync errors to keep the chat flow responsive
    }
  }

  List<WorkspaceMember> _membersFromList(Object? raw) {
    final list = raw as List<dynamic>? ?? const [];
    return list
        .map((item) => WorkspaceMember.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  WorkspaceMember? _memberFromPayload(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    return WorkspaceMember.fromJson(raw);
  }
}

extension _FirstWhereOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
