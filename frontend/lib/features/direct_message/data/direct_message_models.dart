class DirectConversation {
  const DirectConversation({
    required this.id,
    required this.peerUserId,
    required this.peerName,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.peerLastReadMessageId,
    required this.peerLastReadAt,
    required this.unreadCount,
  });

  final int id;
  final int peerUserId;
  final String peerName;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int peerLastReadMessageId;
  final DateTime peerLastReadAt;
  final int unreadCount;

  factory DirectConversation.fromJson(Map<String, dynamic> json) {
    return DirectConversation(
      id: json['id'] as int,
      peerUserId: json['peer_user_id'] as int,
      peerName: json['peer_name'] as String? ?? 'Unknown',
      lastMessage: json['last_message'] as String? ?? '',
      lastMessageAt: DateTime.parse(json['last_message_at'] as String),
      peerLastReadMessageId: json['peer_last_read_message_id'] as int? ?? 0,
      peerLastReadAt: DateTime.parse(json['peer_last_read_at'] as String),
      unreadCount: json['unread_count'] as int? ?? 0,
    );
  }

  DirectConversation copyWith({
    int? id,
    int? peerUserId,
    String? peerName,
    String? lastMessage,
    DateTime? lastMessageAt,
    int? peerLastReadMessageId,
    DateTime? peerLastReadAt,
    int? unreadCount,
  }) {
    return DirectConversation(
      id: id ?? this.id,
      peerUserId: peerUserId ?? this.peerUserId,
      peerName: peerName ?? this.peerName,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      peerLastReadMessageId:
          peerLastReadMessageId ?? this.peerLastReadMessageId,
      peerLastReadAt: peerLastReadAt ?? this.peerLastReadAt,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

class DirectMessage {
  const DirectMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderDisplayName,
    required this.content,
    required this.createdAt,
  });

  final int id;
  final int conversationId;
  final int senderId;
  final String senderDisplayName;
  final String content;
  final DateTime createdAt;

  factory DirectMessage.fromJson(Map<String, dynamic> json) {
    return DirectMessage(
      id: json['id'] as int,
      conversationId: json['conversation_id'] as int,
      senderId: json['sender_id'] as int,
      senderDisplayName: json['sender_display_name'] as String? ?? 'Unknown',
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class DirectReadState {
  const DirectReadState({
    required this.userId,
    required this.lastReadMessageId,
    required this.lastReadAt,
  });

  final int userId;
  final int lastReadMessageId;
  final DateTime lastReadAt;

  factory DirectReadState.fromJson(Map<String, dynamic> json) {
    return DirectReadState(
      userId: json['user_id'] as int,
      lastReadMessageId: json['last_read_message_id'] as int? ?? 0,
      lastReadAt: DateTime.parse(json['last_read_at'] as String),
    );
  }
}
