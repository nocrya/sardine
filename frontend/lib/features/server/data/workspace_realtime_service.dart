import 'dart:async';
import 'dart:convert';

import 'package:sardine/core/constants/app_constants.dart';
import 'package:sardine/features/auth/data/auth_remote_datasource.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WorkspaceRealtimeEvent {
  const WorkspaceRealtimeEvent({
    required this.type,
    required this.payload,
  });

  final String type;
  final Map<String, dynamic> payload;

  factory WorkspaceRealtimeEvent.fromJson(Map<String, dynamic> json) {
    return WorkspaceRealtimeEvent(
      type: json['type'] as String? ?? '',
      payload: json['payload'] as Map<String, dynamic>? ?? const {},
    );
  }
}

class WorkspaceRealtimeService {
  WorkspaceRealtimeService(this._authRemoteDataSource);

  final AuthRemoteDataSource _authRemoteDataSource;
  final _controller = StreamController<WorkspaceRealtimeEvent>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  int? _subscribedChannelId;
  int? _subscribedDirectConversationId;

  Stream<WorkspaceRealtimeEvent> get events => _controller.stream;

  Future<void> connect() async {
    if (_channel != null) {
      return;
    }

    final session = _authRemoteDataSource.loadSession();
    final token = session?.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }

    final channel = WebSocketChannel.connect(AppConstants.websocketUri(token));
    _channel = channel;
    _subscription = channel.stream.listen(
      (data) {
        if (data is! String) {
          return;
        }
        final decoded = jsonDecode(data) as Map<String, dynamic>;
        _controller.add(WorkspaceRealtimeEvent.fromJson(decoded));
      },
      onDone: _resetSocket,
      onError: (_) => _resetSocket(),
    );
  }

  Future<void> subscribeToChannel(int channelId) async {
    await connect();
    final channel = _channel;
    if (channel == null) {
      return;
    }

    if (_subscribedChannelId != null && _subscribedChannelId != channelId) {
      channel.sink.add(
        jsonEncode({
          'type': 'unsubscribe',
          'channel_id': _subscribedChannelId,
        }),
      );
    }

    _subscribedChannelId = channelId;
    channel.sink.add(
      jsonEncode({
        'type': 'subscribe',
        'channel_id': channelId,
      }),
    );
  }

  Future<void> subscribeToDirectConversation(int conversationId) async {
    await connect();
    final channel = _channel;
    if (channel == null) {
      return;
    }

    if (_subscribedDirectConversationId != null &&
        _subscribedDirectConversationId != conversationId) {
      channel.sink.add(
        jsonEncode({
          'type': 'direct.unsubscribe',
          'conversation_id': _subscribedDirectConversationId,
        }),
      );
    }

    _subscribedDirectConversationId = conversationId;
    channel.sink.add(
      jsonEncode({
        'type': 'direct.subscribe',
        'conversation_id': conversationId,
      }),
    );
  }

  void syncServerPresence(int serverId) {
    _sendCommand('presence.sync', serverId: serverId);
  }

  void sendTypingStart(int channelId) {
    _sendCommand('typing.start', channelId: channelId);
  }

  void sendTypingStop(int channelId) {
    _sendCommand('typing.stop', channelId: channelId);
  }

  void sendDirectTypingStart(int conversationId) {
    _sendCommand('direct.typing.start', conversationId: conversationId);
  }

  void sendDirectTypingStop(int conversationId) {
    _sendCommand('direct.typing.stop', conversationId: conversationId);
  }

  void markDirectRead(int conversationId, int messageId) {
    _sendCommand(
      'direct.read',
      conversationId: conversationId,
      messageId: messageId,
    );
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    await _channel?.sink.close();
    _resetSocket();
  }

  void _resetSocket() {
    _channel = null;
    _subscription = null;
    _subscribedChannelId = null;
    _subscribedDirectConversationId = null;
  }

  void _sendCommand(
    String type, {
    int? channelId,
    int? serverId,
    int? conversationId,
    int? messageId,
  }) {
    final channel = _channel;
    if (channel == null) {
      return;
    }

    channel.sink.add(
      jsonEncode({
        'type': type,
        if (channelId != null) 'channel_id': channelId,
        if (serverId != null) 'server_id': serverId,
        if (conversationId != null) 'conversation_id': conversationId,
        if (messageId != null) 'message_id': messageId,
      }),
    );
  }
}
