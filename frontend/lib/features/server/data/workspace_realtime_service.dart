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
  static const Duration _reconnectBaseDelay = Duration(seconds: 1);
  static const Duration _reconnectMaxDelay = Duration(seconds: 8);

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  Future<void>? _connectFuture;
  int _reconnectAttempt = 0;
  bool _manualDisconnect = false;
  int? _subscribedChannelId;
  int? _subscribedDirectConversationId;
  int? _serverPresenceId;

  Stream<WorkspaceRealtimeEvent> get events => _controller.stream;

  Future<void> connect() async {
    if (_channel != null || _connectFuture != null) {
      await _connectFuture;
      return;
    }

    _manualDisconnect = false;
    _connectFuture = _openSocket();
    try {
      await _connectFuture;
    } finally {
      _connectFuture = null;
    }
  }

  Future<void> subscribeToChannel(int channelId) async {
    final previousChannelId = _subscribedChannelId;
    _subscribedChannelId = channelId;
    await connect();
    final channel = _channel;
    if (channel == null) {
      return;
    }

    if (previousChannelId != null && previousChannelId != channelId) {
      channel.sink.add(
        jsonEncode({
          'type': 'unsubscribe',
          'channel_id': previousChannelId,
        }),
      );
    }

    _sendCommand('subscribe', channelId: channelId);
  }

  Future<void> subscribeToDirectConversation(int conversationId) async {
    final previousConversationId = _subscribedDirectConversationId;
    _subscribedDirectConversationId = conversationId;
    await connect();
    final channel = _channel;
    if (channel == null) {
      return;
    }

    if (previousConversationId != null &&
        previousConversationId != conversationId) {
      channel.sink.add(
        jsonEncode({
          'type': 'direct.unsubscribe',
          'conversation_id': previousConversationId,
        }),
      );
    }

    _sendCommand('direct.subscribe', conversationId: conversationId);
  }

  void syncServerPresence(int serverId) {
    _serverPresenceId = serverId;
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
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _subscription?.cancel();
    await _channel?.sink.close();
    _resetSocket(clearDesiredState: true);
  }

  Future<void> _openSocket() async {
    final session = _authRemoteDataSource.loadSession();
    final token = session?.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    final channel = WebSocketChannel.connect(AppConstants.websocketUri(token));
    _channel = channel;
    _subscription = channel.stream.listen(
      (data) {
        if (data is! String) {
          return;
        }
        _reconnectAttempt = 0;
        final decoded = jsonDecode(data) as Map<String, dynamic>;
        _controller.add(WorkspaceRealtimeEvent.fromJson(decoded));
      },
      onDone: _handleSocketClosed,
      onError: (_) => _handleSocketClosed(),
    );

    _restoreDesiredSubscriptions();
  }

  void _handleSocketClosed() {
    final shouldReconnect = !_manualDisconnect;
    _resetSocket(clearDesiredState: false);
    if (shouldReconnect) {
      _scheduleReconnect();
    }
  }

  void _resetSocket({required bool clearDesiredState}) {
    _channel = null;
    _subscription = null;
    if (clearDesiredState) {
      _subscribedChannelId = null;
      _subscribedDirectConversationId = null;
      _serverPresenceId = null;
    }
  }

  void _scheduleReconnect() {
    if (_reconnectTimer != null || _connectFuture != null) {
      return;
    }
    final session = _authRemoteDataSource.loadSession();
    final token = session?.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }

    final delaySeconds = 1 << (_reconnectAttempt.clamp(0, 3));
    final delay = Duration(
      seconds: delaySeconds.clamp(
        _reconnectBaseDelay.inSeconds,
        _reconnectMaxDelay.inSeconds,
      ),
    );
    _reconnectAttempt += 1;

    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      connect();
    });
  }

  void _restoreDesiredSubscriptions() {
    if (_serverPresenceId != null) {
      _sendCommand('presence.sync', serverId: _serverPresenceId);
    }
    if (_subscribedChannelId != null) {
      _sendCommand('subscribe', channelId: _subscribedChannelId);
    }
    if (_subscribedDirectConversationId != null) {
      _sendCommand(
        'direct.subscribe',
        conversationId: _subscribedDirectConversationId,
      );
    }
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
