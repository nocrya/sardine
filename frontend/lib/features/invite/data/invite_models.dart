class InvitePreview {
  const InvitePreview({
    required this.code,
    required this.serverId,
    required this.serverName,
    required this.serverDescription,
    required this.role,
    required this.useCount,
    required this.maxUses,
    required this.memberCount,
    required this.channelCount,
    required this.expired,
    required this.inviteLink,
  });

  final String code;
  final int serverId;
  final String serverName;
  final String serverDescription;
  final String role;
  final int useCount;
  final int maxUses;
  final int memberCount;
  final int channelCount;
  final bool expired;
  final String inviteLink;

  factory InvitePreview.fromJson(Map<String, dynamic> json) {
    return InvitePreview(
      code: json['code'] as String? ?? '',
      serverId: json['server_id'] as int? ?? 0,
      serverName: json['server_name'] as String? ?? 'Unknown server',
      serverDescription: json['server_description'] as String? ?? '',
      role: json['role'] as String? ?? 'member',
      useCount: json['use_count'] as int? ?? 0,
      maxUses: json['max_uses'] as int? ?? 0,
      memberCount: json['member_count'] as int? ?? 0,
      channelCount: json['channel_count'] as int? ?? 0,
      expired: json['expired'] as bool? ?? false,
      inviteLink: json['invite_link'] as String? ?? '',
    );
  }
}
