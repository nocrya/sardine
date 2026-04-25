import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:sardine/core/di/dependency_injection.dart';
import 'package:sardine/features/auth/data/auth_remote_datasource.dart';
import 'package:sardine/features/server/data/server_models.dart';
import 'package:sardine/features/server/data/server_remote_datasource.dart';
import 'package:sardine/features/voice/data/voice_remote_datasource.dart';
import 'package:sardine/features/voice/data/voice_session_data.dart';
import 'package:sardine/shared/widgets/app_gap.dart';

class VoicePage extends StatefulWidget {
  const VoicePage({super.key});

  @override
  State<VoicePage> createState() => _VoicePageState();
}

class _VoicePageState extends State<VoicePage> {
  final _serverDataSource = getIt<ServerRemoteDataSource>();
  final _voiceDataSource = getIt<VoiceRemoteDataSource>();
  final _authDataSource = getIt<AuthRemoteDataSource>();
  final lk.Room _room = lk.Room();

  bool _loading = true;
  bool _joining = false;
  bool _micEnabled = false;
  String? _errorMessage;
  VoiceSessionData? _session;
  List<WorkspaceServer> _servers = const [];
  List<WorkspaceChannel> _voiceChannels = const [];
  WorkspaceServer? _selectedServer;
  WorkspaceChannel? _selectedChannel;

  bool get _authenticated => _authDataSource.loadSession() != null;
  bool get _connected => _session != null;

  @override
  void initState() {
    super.initState();
    _room.addListener(_onRoomChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    _room.removeListener(_onRoomChanged);
    _room.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final participants = <lk.Participant>[
      if (_connected && _room.localParticipant != null) _room.localParticipant!,
      ..._room.remoteParticipants.values.whereType<lk.Participant>(),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Voice Lab')),
      body: !_authenticated
          ? const Center(
              child: Text('Please sign in from the Authentication page first.'),
            )
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  if (_loading)
                    const Expanded(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else ...[
                    _ServerChannelPicker(
                      servers: _servers,
                      selectedServer: _selectedServer,
                      selectedChannel: _selectedChannel,
                      voiceChannels: _voiceChannels,
                      joining: _joining,
                      onServerChanged: _selectServer,
                      onChannelChanged: _selectChannel,
                      onJoin: _joinSelectedChannel,
                      onLeave: _leaveRoom,
                      connected: _connected,
                    ),
                    const AppGap.v(height: 20),
                    _VoiceSessionCard(
                      session: _session,
                      connected: _connected,
                      micEnabled: _micEnabled,
                      onToggleMic: _toggleMic,
                    ),
                    const AppGap.v(height: 20),
                    Expanded(
                      child: _ParticipantList(
                        participants: participants,
                        connected: _connected,
                      ),
                    ),
                  ],
                ],
              ),
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
      final servers = await _serverDataSource.listServers();
      WorkspaceServer? selectedServer;
      List<WorkspaceChannel> voiceChannels = const [];
      WorkspaceChannel? selectedChannel;

      if (servers.isNotEmpty) {
        selectedServer = servers.first;
        voiceChannels = await _loadVoiceChannels(selectedServer.id);
        selectedChannel = voiceChannels.firstOrNull;
      }

      if (!mounted) return;
      setState(() {
        _loading = false;
        _servers = servers;
        _selectedServer = selectedServer;
        _voiceChannels = voiceChannels;
        _selectedChannel = selectedChannel;
      });
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = _messageFrom(error);
      });
    }
  }

  Future<void> _selectServer(WorkspaceServer? server) async {
    if (server == null) return;
    setState(() {
      _loading = true;
      _selectedServer = server;
      _voiceChannels = const [];
      _selectedChannel = null;
      _errorMessage = null;
    });

    try {
      final channels = await _loadVoiceChannels(server.id);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _voiceChannels = channels;
        _selectedChannel = channels.firstOrNull;
      });
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = _messageFrom(error);
      });
    }
  }

  void _selectChannel(WorkspaceChannel? channel) {
    setState(() {
      _selectedChannel = channel;
    });
  }

  Future<void> _joinSelectedChannel() async {
    final channel = _selectedChannel;
    if (channel == null) return;

    setState(() {
      _joining = true;
      _errorMessage = null;
    });

    try {
      await lk.LiveKitClient.initialize();
      await _room.disconnect();
      final session = await _voiceDataSource.joinVoiceChannel(channel.id);
      await _room.connect(
        session.serverUrl,
        session.accessToken,
        connectOptions: const lk.ConnectOptions(
          timeouts: lk.Timeouts(
            connection: Duration(seconds: 30),
            debounce: Duration(milliseconds: 20),
            publish: Duration(seconds: 30),
            subscribe: Duration(seconds: 30),
            peerConnection: Duration(seconds: 45),
            iceRestart: Duration(seconds: 30),
          ),
        ),
        roomOptions: const lk.RoomOptions(
          adaptiveStream: true,
          dynacast: true,
        ),
      );
      await _room.localParticipant?.setMicrophoneEnabled(true);

      if (!mounted) return;
      setState(() {
        _joining = false;
        _session = session;
        _micEnabled = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _joining = false;
        _errorMessage =
            error is DioException ? _messageFrom(error) : error.toString();
      });
    }
  }

  Future<void> _leaveRoom() async {
    await _room.disconnect();
    if (!mounted) return;
    setState(() {
      _session = null;
      _micEnabled = false;
    });
  }

  Future<void> _toggleMic() async {
    if (!_connected) return;
    final next = !_micEnabled;
    try {
      await _room.localParticipant?.setMicrophoneEnabled(next);
      if (!mounted) return;
      setState(() {
        _micEnabled = next;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
      });
    }
  }

  Future<List<WorkspaceChannel>> _loadVoiceChannels(int serverId) async {
    final channels = await _serverDataSource.listChannels(serverId);
    return channels.where((item) => item.kind == 'voice').toList();
  }

  void _onRoomChanged() {
    if (!mounted) return;
    setState(() {});
  }

  String _messageFrom(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic> && data['error'] is String) {
      return data['error'] as String;
    }
    return error.message ?? 'Voice request failed';
  }
}

class _ServerChannelPicker extends StatelessWidget {
  const _ServerChannelPicker({
    required this.servers,
    required this.selectedServer,
    required this.selectedChannel,
    required this.voiceChannels,
    required this.joining,
    required this.onServerChanged,
    required this.onChannelChanged,
    required this.onJoin,
    required this.onLeave,
    required this.connected,
  });

  final List<WorkspaceServer> servers;
  final WorkspaceServer? selectedServer;
  final WorkspaceChannel? selectedChannel;
  final List<WorkspaceChannel> voiceChannels;
  final bool joining;
  final ValueChanged<WorkspaceServer?> onServerChanged;
  final ValueChanged<WorkspaceChannel?> onChannelChanged;
  final VoidCallback onJoin;
  final VoidCallback onLeave;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Join Voice Channel',
                style: Theme.of(context).textTheme.titleLarge),
            const AppGap.v(height: 16),
            DropdownButtonFormField<WorkspaceServer>(
              value: selectedServer,
              items: servers
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(item.name),
                    ),
                  )
                  .toList(),
              onChanged: onServerChanged,
              decoration: const InputDecoration(
                labelText: 'Server',
                border: OutlineInputBorder(),
              ),
            ),
            const AppGap.v(height: 12),
            DropdownButtonFormField<WorkspaceChannel>(
              value: selectedChannel,
              items: voiceChannels
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(item.name),
                    ),
                  )
                  .toList(),
              onChanged: onChannelChanged,
              decoration: const InputDecoration(
                labelText: 'Voice channel',
                border: OutlineInputBorder(),
              ),
            ),
            const AppGap.v(height: 12),
            Row(
              children: [
                FilledButton(
                  onPressed: joining || selectedChannel == null || connected
                      ? null
                      : onJoin,
                  child: Text(joining ? 'Joining...' : 'Join room'),
                ),
                const AppGap.h(width: 12),
                OutlinedButton(
                  onPressed: connected ? onLeave : null,
                  child: const Text('Leave room'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceSessionCard extends StatelessWidget {
  const _VoiceSessionCard({
    required this.session,
    required this.connected,
    required this.micEnabled,
    required this.onToggleMic,
  });

  final VoiceSessionData? session;
  final bool connected;
  final bool micEnabled;
  final VoidCallback onToggleMic;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Room Status', style: Theme.of(context).textTheme.titleLarge),
            const AppGap.v(height: 12),
            Text(connected ? 'Connected' : 'Not connected'),
            if (session != null) ...[
              const AppGap.v(height: 8),
              Text('Room: ${session!.roomName}'),
              const AppGap.v(height: 4),
              Text('Participant: ${session!.participantName}'),
            ],
            const AppGap.v(height: 12),
            FilledButton.tonal(
              onPressed: connected ? onToggleMic : null,
              child: Text(micEnabled ? 'Mute microphone' : 'Unmute microphone'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParticipantList extends StatelessWidget {
  const _ParticipantList({
    required this.participants,
    required this.connected,
  });

  final List<lk.Participant> participants;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    if (!connected) {
      return const Center(
        child:
            Text('Join a voice room to inspect members and microphone state.'),
      );
    }

    if (participants.isEmpty) {
      return const Center(child: Text('No participants in the room yet.'));
    }

    return Card(
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: participants.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final participant = participants[index];
          final name = participant.name.isEmpty
              ? participant.identity
              : participant.name;
          final status =
              participant.isMicrophoneEnabled() ? 'mic on' : 'mic off';
          final speaking = participant.isSpeaking ? 'speaking' : 'idle';
          return ListTile(
            title: Text(name),
            subtitle: Text('${participant.identity} · $status · $speaking'),
          );
        },
      ),
    );
  }
}

extension _FirstWhereOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
