class VoiceSessionData {
  const VoiceSessionData({
    required this.channelId,
    required this.roomName,
    required this.serverUrl,
    required this.accessToken,
    required this.participantIdentity,
    required this.participantName,
  });

  final int channelId;
  final String roomName;
  final String serverUrl;
  final String accessToken;
  final String participantIdentity;
  final String participantName;

  factory VoiceSessionData.fromJson(Map<String, dynamic> json) {
    return VoiceSessionData(
      channelId: json['channel_id'] as int,
      roomName: json['room_name'] as String,
      serverUrl: json['server_url'] as String,
      accessToken: json['access_token'] as String,
      participantIdentity: json['participant_identity'] as String,
      participantName: json['participant_name'] as String,
    );
  }
}
