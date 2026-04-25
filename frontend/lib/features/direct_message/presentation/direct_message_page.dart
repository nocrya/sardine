import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sardine/core/di/dependency_injection.dart';
import 'package:sardine/features/auth/data/auth_remote_datasource.dart';
import 'package:sardine/features/direct_message/data/direct_message_models.dart';
import 'package:sardine/features/direct_message/data/direct_message_remote_datasource.dart';
import 'package:sardine/features/server/data/workspace_realtime_service.dart';
import 'package:sardine/shared/widgets/app_gap.dart';

class DirectMessagePage extends StatefulWidget {
  const DirectMessagePage({super.key});

  @override
  State<DirectMessagePage> createState() => _DirectMessagePageState();
}

class _DirectMessagePageState extends State<DirectMessagePage> {
  final _dataSource = getIt<DirectMessageRemoteDataSource>();
  final _authDataSource = getIt<AuthRemoteDataSource>();
  final _realtimeService = getIt<WorkspaceRealtimeService>();
  final _peerUserIdController = TextEditingController();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  StreamSubscription<WorkspaceRealtimeEvent>? _realtimeSubscription;
  Timer? _typingStopTimer;

  bool _loading = true;
  bool _submitting = false;
  String? _errorMessage;
  List<DirectConversation> _conversations = const [];
  List<DirectMessage> _messages = const [];
  List<String> _typingNames = const [];
  List<int> _onlineUserIds = const [];
  Map<int, DirectReadState> _readStates = const {};
  DirectConversation? _selectedConversation;

  bool get _authenticated => _authDataSource.loadSession() != null;
  int? get _currentUserId => _authDataSource.loadSession()?.user.id;

  int get _peerReadMessageId {
    final conversation = _selectedConversation;
    if (conversation == null) return 0;
    return _readStates[conversation.peerUserId]?.lastReadMessageId ??
        conversation.peerLastReadMessageId;
  }

  bool get _peerOnline {
    final conversation = _selectedConversation;
    if (conversation == null) return false;
    return _onlineUserIds.contains(conversation.peerUserId);
  }

  @override
  void initState() {
    super.initState();
    _realtimeSubscription =
        _realtimeService.events.listen(_handleRealtimeEvent);
    _bootstrap();
  }

  @override
  void dispose() {
    _typingStopTimer?.cancel();
    _realtimeSubscription?.cancel();
    final conversation = _selectedConversation;
    if (conversation != null) {
      _realtimeService.sendDirectTypingStop(conversation.id);
    }
    _realtimeService.disconnect();
    _peerUserIdController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Direct Messages')),
      body: !_authenticated
          ? const Center(
              child: Text('Please sign in from the Authentication page first.'),
            )
          : Column(
              children: [
                if (_errorMessage != null)
                  MaterialBanner(
                    content: Text(_errorMessage!),
                    actions: [
                      TextButton(
                        onPressed: _bootstrap,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 900;
                      if (compact) {
                        return ListView(
                          children: [
                            SizedBox(
                              height: 280,
                              child: _ConversationPane(
                                loading: _loading,
                                conversations: _conversations,
                                selectedConversation: _selectedConversation,
                                peerUserIdController: _peerUserIdController,
                                onCreateConversation: _createConversation,
                                onSelect: _selectConversation,
                              ),
                            ),
                            const Divider(height: 1),
                            SizedBox(
                              height: 620,
                              child: _MessagePane(
                                conversation: _selectedConversation,
                                messages: _messages,
                                messageController: _messageController,
                                scrollController: _scrollController,
                                submitting: _submitting,
                                typingNames: _typingNames,
                                peerReadMessageId: _peerReadMessageId,
                                peerOnline: _peerOnline,
                                onSend: _sendMessage,
                                onInputChanged: _onInputChanged,
                              ),
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          _ConversationPane(
                            loading: _loading,
                            conversations: _conversations,
                            selectedConversation: _selectedConversation,
                            peerUserIdController: _peerUserIdController,
                            onCreateConversation: _createConversation,
                            onSelect: _selectConversation,
                          ),
                          const VerticalDivider(width: 1),
                          Expanded(
                            child: _MessagePane(
                              conversation: _selectedConversation,
                              messages: _messages,
                              messageController: _messageController,
                              scrollController: _scrollController,
                              submitting: _submitting,
                              typingNames: _typingNames,
                              peerReadMessageId: _peerReadMessageId,
                              peerOnline: _peerOnline,
                              onSend: _sendMessage,
                              onInputChanged: _onInputChanged,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _bootstrap() async {
    if (!_authenticated) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final conversations = await _dataSource.listConversations();
      DirectConversation? selectedConversation;
      List<DirectMessage> messages = const [];

      if (conversations.isNotEmpty) {
        selectedConversation = conversations.first;
        messages = await _dataSource.listMessages(selectedConversation.id);
        await _realtimeService.connect();
        await _realtimeService
            .subscribeToDirectConversation(selectedConversation.id);
      }

      if (!mounted) return;
      setState(() {
        _loading = false;
        _conversations = _markConversationUnreadAsRead(
          conversations,
          selectedConversation?.id,
        );
        _selectedConversation = selectedConversation?.copyWith(unreadCount: 0);
        _messages = messages;
        _typingNames = const [];
        _onlineUserIds = const [];
        _readStates = _initialReadStates(selectedConversation);
      });
      _markCurrentConversationRead();
      _scrollToBottom();
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = _messageFrom(error);
      });
    }
  }

  Future<void> _createConversation() async {
    final peerUserId = int.tryParse(_peerUserIdController.text.trim());
    if (peerUserId == null || peerUserId <= 0) {
      setState(() {
        _errorMessage = 'Peer user id must be a positive integer';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final conversationId = await _dataSource.createConversation(peerUserId);
      final conversations = await _dataSource.listConversations();
      final selectedConversation =
          conversations.where((item) => item.id == conversationId).firstOrNull;
      final messages = selectedConversation == null
          ? const <DirectMessage>[]
          : await _dataSource.listMessages(selectedConversation.id);

      if (selectedConversation != null) {
        await _realtimeService.connect();
        await _realtimeService
            .subscribeToDirectConversation(selectedConversation.id);
      }

      if (!mounted) return;
      _peerUserIdController.clear();
      setState(() {
        _submitting = false;
        _conversations = _markConversationUnreadAsRead(
          conversations,
          selectedConversation?.id,
        );
        _selectedConversation = selectedConversation?.copyWith(unreadCount: 0);
        _messages = messages;
        _typingNames = const [];
        _onlineUserIds = const [];
        _readStates = _initialReadStates(selectedConversation);
      });
      _markCurrentConversationRead();
      _scrollToBottom();
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = _messageFrom(error);
      });
    }
  }

  Future<void> _selectConversation(DirectConversation conversation) async {
    setState(() {
      _loading = true;
      _selectedConversation = conversation.copyWith(unreadCount: 0);
      _conversations = _markConversationUnreadAsRead(
        _conversations,
        conversation.id,
      );
      _messages = const [];
      _typingNames = const [];
      _onlineUserIds = const [];
      _readStates = _initialReadStates(conversation);
      _errorMessage = null;
    });

    try {
      final messages = await _dataSource.listMessages(conversation.id);
      await _realtimeService.connect();
      await _realtimeService.subscribeToDirectConversation(conversation.id);

      if (!mounted) return;
      setState(() {
        _loading = false;
        _messages = messages;
      });
      _markCurrentConversationRead();
      _scrollToBottom();
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = _messageFrom(error);
      });
    }
  }

  Future<void> _sendMessage() async {
    final conversation = _selectedConversation;
    final text = _messageController.text.trim();
    if (conversation == null || text.isEmpty) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final message = await _dataSource.createMessage(
        conversationId: conversation.id,
        content: text,
      );

      if (!mounted) return;
      _messageController.clear();
      _typingStopTimer?.cancel();
      _realtimeService.sendDirectTypingStop(conversation.id);
      setState(() {
        _submitting = false;
        _messages = _appendMessage(_messages, message);
        _selectedConversation = conversation.copyWith(
          lastMessage: message.content,
          lastMessageAt: message.createdAt,
          unreadCount: 0,
        );
        _conversations = _upsertConversation(
          _conversations,
          _selectedConversation!,
        );
      });
      _markCurrentConversationRead();
      _scrollToBottom();
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = _messageFrom(error);
      });
    }
  }

  void _onInputChanged(String value) {
    final conversation = _selectedConversation;
    if (conversation == null) return;

    if (value.trim().isEmpty) {
      _typingStopTimer?.cancel();
      _realtimeService.sendDirectTypingStop(conversation.id);
      return;
    }

    _realtimeService.sendDirectTypingStart(conversation.id);
    _typingStopTimer?.cancel();
    _typingStopTimer = Timer(const Duration(seconds: 2), () {
      final selectedConversation = _selectedConversation;
      if (selectedConversation == null) return;
      _realtimeService.sendDirectTypingStop(selectedConversation.id);
    });
  }

  void _handleRealtimeEvent(WorkspaceRealtimeEvent event) {
    final conversation = _selectedConversation;
    if (conversation == null) return;

    final payload = event.payload;
    final conversationId = payload['conversation_id'] as int?;
    if (conversationId == null ||
        conversationId != conversation.id ||
        !mounted) {
      return;
    }

    switch (event.type) {
      case 'direct.message.created':
        final messageJson = payload['message'];
        if (messageJson is! Map<String, dynamic>) return;
        final message = DirectMessage.fromJson(messageJson);
        setState(() {
          _messages = _appendMessage(_messages, message);
          _selectedConversation = conversation.copyWith(
            lastMessage: message.content,
            lastMessageAt: message.createdAt,
            unreadCount: 0,
          );
          _conversations = _upsertConversation(
            _conversations,
            _selectedConversation!,
          );
        });
        _markCurrentConversationRead();
        _scrollToBottom();
        return;
      case 'direct.typing.started':
        final member = payload['member'];
        if (member is! Map<String, dynamic>) return;
        final userId = member['user_id'] as int?;
        final displayName = member['display_name'] as String?;
        if (userId == null || displayName == null || userId == _currentUserId) {
          return;
        }
        setState(() {
          _typingNames = {..._typingNames, displayName}.toList();
        });
        return;
      case 'direct.typing.stopped':
        final member = payload['member'];
        if (member is! Map<String, dynamic>) return;
        final displayName = member['display_name'] as String?;
        if (displayName == null) return;
        setState(() {
          _typingNames =
              _typingNames.where((item) => item != displayName).toList();
        });
        return;
      case 'direct.presence.snapshot':
        final members = payload['members'] as List<dynamic>? ?? const [];
        setState(() {
          _onlineUserIds = members
              .map((item) => item as Map<String, dynamic>)
              .where((item) => item['online'] as bool? ?? false)
              .map((item) => item['user_id'] as int)
              .toList();
        });
        return;
      case 'direct.presence.joined':
        final member = payload['member'];
        if (member is! Map<String, dynamic>) return;
        final userId = member['user_id'] as int?;
        if (userId == null) return;
        setState(() {
          _onlineUserIds = {..._onlineUserIds, userId}.toList();
        });
        return;
      case 'direct.presence.left':
        final member = payload['member'];
        if (member is! Map<String, dynamic>) return;
        final userId = member['user_id'] as int?;
        final displayName = member['display_name'] as String?;
        if (userId == null) return;
        setState(() {
          _onlineUserIds =
              _onlineUserIds.where((item) => item != userId).toList();
          if (displayName != null) {
            _typingNames =
                _typingNames.where((item) => item != displayName).toList();
          }
        });
        return;
      case 'direct.read.snapshot':
        final reads = payload['reads'] as List<dynamic>? ?? const [];
        setState(() {
          _readStates = {
            for (final item in reads)
              DirectReadState.fromJson(item as Map<String, dynamic>).userId:
                  DirectReadState.fromJson(item),
          };
        });
        return;
      case 'direct.read.updated':
        final read = payload['read'];
        if (read is! Map<String, dynamic>) return;
        final state = DirectReadState.fromJson(read);
        setState(() {
          _readStates = {
            ..._readStates,
            state.userId: state,
          };
          if (state.userId == conversation.peerUserId) {
            _selectedConversation = conversation.copyWith(
              peerLastReadMessageId: state.lastReadMessageId,
              peerLastReadAt: state.lastReadAt,
            );
            _conversations = _upsertConversation(
              _conversations,
              _selectedConversation!,
            );
          }
        });
        return;
    }
  }

  void _markCurrentConversationRead() {
    final conversation = _selectedConversation;
    if (conversation == null || _messages.isEmpty) return;
    final latestMessageId = _messages.last.id;
    if (latestMessageId <= 0) return;
    if (mounted && conversation.unreadCount > 0) {
      setState(() {
        _selectedConversation = conversation.copyWith(unreadCount: 0);
        _conversations = _markConversationUnreadAsRead(
          _conversations,
          conversation.id,
        );
      });
    }
    _realtimeService.markDirectRead(conversation.id, latestMessageId);
  }

  Map<int, DirectReadState> _initialReadStates(
      DirectConversation? conversation) {
    if (conversation == null) return const {};
    return {
      conversation.peerUserId: DirectReadState(
        userId: conversation.peerUserId,
        lastReadMessageId: conversation.peerLastReadMessageId,
        lastReadAt: conversation.peerLastReadAt,
      ),
    };
  }

  List<DirectMessage> _appendMessage(
    List<DirectMessage> messages,
    DirectMessage message,
  ) {
    if (messages.any((item) => item.id == message.id)) {
      return messages;
    }
    return [...messages, message]..sort((a, b) => a.id.compareTo(b.id));
  }

  List<DirectConversation> _upsertConversation(
    List<DirectConversation> conversations,
    DirectConversation conversation,
  ) {
    final updated = [
      conversation,
      ...conversations.where((item) => item.id != conversation.id),
    ];
    updated.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
    return updated;
  }

  List<DirectConversation> _markConversationUnreadAsRead(
    List<DirectConversation> conversations,
    int? conversationId,
  ) {
    if (conversationId == null) return conversations;
    return conversations
        .map(
          (item) =>
              item.id == conversationId ? item.copyWith(unreadCount: 0) : item,
        )
        .toList();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  String _messageFrom(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic> && data['error'] is String) {
      return data['error'] as String;
    }
    return error.message ?? 'Direct message request failed';
  }
}

class _ConversationPane extends StatelessWidget {
  const _ConversationPane({
    required this.loading,
    required this.conversations,
    required this.selectedConversation,
    required this.peerUserIdController,
    required this.onCreateConversation,
    required this.onSelect,
  });

  final bool loading;
  final List<DirectConversation> conversations;
  final DirectConversation? selectedConversation;
  final TextEditingController peerUserIdController;
  final VoidCallback onCreateConversation;
  final ValueChanged<DirectConversation> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Conversations',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: peerUserIdController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Peer user id',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const AppGap.h(width: 12),
                FilledButton(
                  onPressed: loading ? null : onCreateConversation,
                  child: const Text('Start'),
                ),
              ],
            ),
          ),
          const AppGap.v(height: 12),
          Expanded(
            child: loading && conversations.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : conversations.isEmpty
                    ? const Center(
                        child:
                            Text('No conversations yet. Start one by user id.'),
                      )
                    : ListView.separated(
                        itemCount: conversations.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final conversation = conversations[index];
                          return ListTile(
                            selected:
                                selectedConversation?.id == conversation.id,
                            title: Text(conversation.peerName),
                            subtitle: conversation.lastMessage.isEmpty
                                ? const Text('No messages yet')
                                : Text(
                                    conversation.lastMessage,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  DateFormat('MM-dd HH:mm').format(
                                    conversation.lastMessageAt.toLocal(),
                                  ),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                if (conversation.unreadCount > 0) ...[
                                  const AppGap.v(height: 6),
                                  _UnreadBadge(count: conversation.unreadCount),
                                ],
                              ],
                            ),
                            onTap: () => onSelect(conversation),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MessagePane extends StatelessWidget {
  const _MessagePane({
    required this.conversation,
    required this.messages,
    required this.messageController,
    required this.scrollController,
    required this.submitting,
    required this.typingNames,
    required this.peerReadMessageId,
    required this.peerOnline,
    required this.onSend,
    required this.onInputChanged,
  });

  final DirectConversation? conversation;
  final List<DirectMessage> messages;
  final TextEditingController messageController;
  final ScrollController scrollController;
  final bool submitting;
  final List<String> typingNames;
  final int peerReadMessageId;
  final bool peerOnline;
  final VoidCallback onSend;
  final ValueChanged<String> onInputChanged;

  @override
  Widget build(BuildContext context) {
    final conversation = this.conversation;
    if (conversation == null) {
      return const Center(
        child: Text('Pick a conversation to view and send messages.'),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            conversation.peerName,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const AppGap.v(height: 4),
          Text(
            'Peer user id: ${conversation.peerUserId}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const AppGap.v(height: 4),
          Text(
            peerOnline ? 'Online now' : 'Offline',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const AppGap.v(height: 16),
          Expanded(
            child: messages.isEmpty
                ? const Center(
                    child: Text('No direct messages yet. Send the first one.'),
                  )
                : ListView.separated(
                    controller: scrollController,
                    itemCount: messages.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final readByPeer =
                          message.senderId != conversation.peerUserId &&
                              message.id <= peerReadMessageId;
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message.senderDisplayName,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const AppGap.v(height: 4),
                              Text(
                                DateFormat('MM-dd HH:mm')
                                    .format(message.createdAt.toLocal()),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const AppGap.v(height: 8),
                              Text(message.content),
                              if (readByPeer) ...[
                                const AppGap.v(height: 8),
                                Text(
                                  '已读',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (typingNames.isNotEmpty) ...[
            const AppGap.v(height: 8),
            Text(
              '${typingNames.join(', ')} 正在输入...',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const AppGap.v(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: messageController,
                  minLines: 1,
                  maxLines: 4,
                  onChanged: onInputChanged,
                  decoration: InputDecoration(
                    hintText: 'Message ${conversation.peerName}',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const AppGap.h(width: 12),
              FilledButton(
                onPressed: submitting ? null : onSend,
                child: Text(submitting ? 'Sending...' : 'Send'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

extension _FirstWhereOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
