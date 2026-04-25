enum WorkspaceMessageStatus { sent, sending, failed }

class WorkspaceMember {
  const WorkspaceMember({
    required this.userId,
    required this.displayName,
    required this.lastActive,
    required this.online,
  });

  final int userId;
  final String displayName;
  final DateTime lastActive;
  final bool online;

  factory WorkspaceMember.fromJson(Map<String, dynamic> json) {
    return WorkspaceMember(
      userId: json['user_id'] as int,
      displayName: json['display_name'] as String,
      lastActive: DateTime.parse(json['last_active'] as String),
      online: json['online'] as bool? ?? false,
    );
  }
}

class WorkspaceServerRoleMember {
  const WorkspaceServerRoleMember({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.role,
    required this.joinedAt,
  });

  final int userId;
  final String email;
  final String displayName;
  final String role;
  final DateTime joinedAt;

  factory WorkspaceServerRoleMember.fromJson(Map<String, dynamic> json) {
    return WorkspaceServerRoleMember(
      userId: json['user_id'] as int,
      email: json['email'] as String,
      displayName: json['display_name'] as String,
      role: json['role'] as String? ?? 'member',
      joinedAt: DateTime.parse(json['joined_at'] as String),
    );
  }
}

class WorkspaceServer {
  const WorkspaceServer({
    required this.id,
    required this.name,
    required this.description,
    required this.ownerId,
    required this.memberRole,
    required this.unreadCount,
  });

  final int id;
  final String name;
  final String description;
  final int ownerId;
  final String memberRole;
  final int unreadCount;

  factory WorkspaceServer.fromJson(Map<String, dynamic> json) {
    return WorkspaceServer(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      ownerId: json['owner_id'] as int,
      memberRole: json['member_role'] as String? ?? 'member',
      unreadCount: json['unread_count'] as int? ?? 0,
    );
  }

  WorkspaceServer copyWith({
    int? id,
    String? name,
    String? description,
    int? ownerId,
    String? memberRole,
    int? unreadCount,
  }) {
    return WorkspaceServer(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      ownerId: ownerId ?? this.ownerId,
      memberRole: memberRole ?? this.memberRole,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

class WorkspaceChannel {
  const WorkspaceChannel({
    required this.id,
    required this.serverId,
    required this.name,
    required this.kind,
    required this.topic,
    required this.unreadCount,
  });

  final int id;
  final int serverId;
  final String name;
  final String kind;
  final String topic;
  final int unreadCount;

  bool get isText => kind == 'text';

  factory WorkspaceChannel.fromJson(Map<String, dynamic> json) {
    return WorkspaceChannel(
      id: json['id'] as int,
      serverId: json['server_id'] as int,
      name: json['name'] as String,
      kind: json['kind'] as String,
      topic: json['topic'] as String? ?? '',
      unreadCount: json['unread_count'] as int? ?? 0,
    );
  }

  WorkspaceChannel copyWith({
    int? id,
    int? serverId,
    String? name,
    String? kind,
    String? topic,
    int? unreadCount,
  }) {
    return WorkspaceChannel(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      topic: topic ?? this.topic,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

class WorkspaceMessage {
  const WorkspaceMessage({
    required this.id,
    required this.channelId,
    required this.senderId,
    required this.senderDisplayName,
    required this.content,
    required this.createdAt,
    this.status = WorkspaceMessageStatus.sent,
    this.clientId,
  });

  final int id;
  final int channelId;
  final int senderId;
  final String senderDisplayName;
  final String content;
  final DateTime createdAt;
  final WorkspaceMessageStatus status;
  final String? clientId;

  factory WorkspaceMessage.fromJson(Map<String, dynamic> json) {
    return WorkspaceMessage(
      id: json['id'] as int,
      channelId: json['channel_id'] as int,
      senderId: json['sender_id'] as int,
      senderDisplayName: json['sender_display_name'] as String? ?? 'Unknown',
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  WorkspaceMessage copyWith({
    int? id,
    int? channelId,
    int? senderId,
    String? senderDisplayName,
    String? content,
    DateTime? createdAt,
    WorkspaceMessageStatus? status,
    String? clientId,
  }) {
    return WorkspaceMessage(
      id: id ?? this.id,
      channelId: channelId ?? this.channelId,
      senderId: senderId ?? this.senderId,
      senderDisplayName: senderDisplayName ?? this.senderDisplayName,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      clientId: clientId ?? this.clientId,
    );
  }
}

class WorkspaceMessagePage {
  const WorkspaceMessagePage({
    required this.messages,
    required this.hasMore,
    required this.nextBeforeId,
  });

  final List<WorkspaceMessage> messages;
  final bool hasMore;
  final int nextBeforeId;

  factory WorkspaceMessagePage.fromJson(Map<String, dynamic> json) {
    final data = json['messages'] as List<dynamic>? ?? [];
    return WorkspaceMessagePage(
      messages: data
          .map(
              (item) => WorkspaceMessage.fromJson(item as Map<String, dynamic>))
          .toList(),
      hasMore: json['has_more'] as bool? ?? false,
      nextBeforeId: json['next_before_id'] as int? ?? 0,
    );
  }
}

class WorkspaceServerInvite {
  const WorkspaceServerInvite({
    required this.code,
    required this.serverId,
    required this.role,
    required this.useCount,
    required this.maxUses,
    required this.inviteLink,
  });

  final String code;
  final int serverId;
  final String role;
  final int useCount;
  final int maxUses;
  final String inviteLink;

  factory WorkspaceServerInvite.fromJson(Map<String, dynamic> json) {
    return WorkspaceServerInvite(
      code: json['code'] as String,
      serverId: json['server_id'] as int,
      role: json['role'] as String? ?? 'member',
      useCount: json['use_count'] as int? ?? 0,
      maxUses: json['max_uses'] as int? ?? 0,
      inviteLink: json['invite_link'] as String? ?? '',
    );
  }
}
