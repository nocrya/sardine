import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:sardine/core/di/dependency_injection.dart';
import 'package:sardine/features/server/data/server_models.dart';
import 'package:sardine/features/server/data/server_remote_datasource.dart';
import 'package:sardine/features/server/data/workspace_realtime_service.dart';
import 'package:sardine/features/server/presentation/server_cubit.dart';
import 'package:sardine/shared/widgets/app_gap.dart';

class ServerPage extends StatelessWidget {
  const ServerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ServerCubit(
        getIt<ServerRemoteDataSource>(),
        getIt(),
        getIt<WorkspaceRealtimeService>(),
      )..bootstrap(),
      child: const _ServerView(),
    );
  }
}

class _ServerView extends StatefulWidget {
  const _ServerView();

  @override
  State<_ServerView> createState() => _ServerViewState();
}

class _ServerViewState extends State<_ServerView> {
  final _messageController = TextEditingController();
  final _messageScrollController = ScrollController();
  final _inviteEmailController = TextEditingController();
  Timer? _typingStopTimer;
  int? _lastChannelId;
  int _lastMessageCount = 0;
  String _inviteRole = 'member';

  @override
  void dispose() {
    _typingStopTimer?.cancel();
    _messageController.dispose();
    _messageScrollController.dispose();
    _inviteEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Server Workspace'),
        actions: [
          IconButton(
            onPressed: () => _showJoinByInviteDialog(context),
            icon: const Icon(Icons.link),
            tooltip: 'Join by invite code',
          ),
          IconButton(
            onPressed: () => _confirmLeaveServer(context),
            icon: const Icon(Icons.logout),
            tooltip: 'Leave selected server',
          ),
          IconButton(
            onPressed: () => _showCreateServerDialog(context),
            icon: const Icon(Icons.add_business_outlined),
            tooltip: 'Create server',
          ),
        ],
      ),
      body: BlocConsumer<ServerCubit, ServerViewState>(
        listener: (context, state) {
          final channelChanged = _lastChannelId != state.selectedChannel?.id;
          final appendedMessage = state.messages.length > _lastMessageCount &&
              !state.loadingOlderMessages;

          _lastChannelId = state.selectedChannel?.id;
          _lastMessageCount = state.messages.length;

          if (!channelChanged && !appendedMessage) return;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_messageScrollController.hasClients) return;
            _messageScrollController.animateTo(
              _messageScrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
            );
          });
        },
        builder: (context, state) {
          if (!state.authenticated) {
            return const Center(
              child: Text('Please sign in from the Authentication page first.'),
            );
          }

          return Column(
            children: [
              if (state.errorMessage != null)
                MaterialBanner(
                  content: Text(state.errorMessage!),
                  actions: [
                    TextButton(
                      onPressed: () => context.read<ServerCubit>().bootstrap(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              if (state.messageFeedback != null)
                MaterialBanner(
                  content: Text(state.messageFeedback!),
                  actions: [
                    TextButton(
                      onPressed: () =>
                          context.read<ServerCubit>().clearMessageFeedback(),
                      child: const Text('Dismiss'),
                    ),
                  ],
                ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 1100;
                    if (compact) {
                      return ListView(
                        children: [
                          SizedBox(
                            height: 220,
                            child: _ServersPane(
                              servers: state.servers,
                              selectedServer: state.selectedServer,
                              loading: state.loading,
                              onSelect: (server) => context
                                  .read<ServerCubit>()
                                  .selectServer(server),
                            ),
                          ),
                          const Divider(height: 1),
                          SizedBox(
                            height: 260,
                            child: _ChannelsPane(
                              channels: state.channels,
                              selectedChannel: state.selectedChannel,
                              canManageChannels: state.canManageChannels,
                              onCreateChannel: () =>
                                  _showCreateChannelDialog(context),
                              onSelect: (channel) => context
                                  .read<ServerCubit>()
                                  .selectChannel(channel),
                            ),
                          ),
                          const Divider(height: 1),
                          SizedBox(
                            height: 620,
                            child: _MessagesPane(
                              selectedServer: state.selectedServer,
                              selectedChannel: state.selectedChannel,
                              messages: state.messages,
                              messageController: _messageController,
                              scrollController: _messageScrollController,
                              submitting: state.submittingMessage,
                              loadingOlderMessages: state.loadingOlderMessages,
                              hasMoreMessages: state.hasMoreMessages,
                              onlineMembers: state.onlineMembers,
                              typingMembers: state.typingMembers,
                              serverMembers: state.serverMembers,
                              onSend: () => _send(context),
                              onLoadOlder: () => context
                                  .read<ServerCubit>()
                                  .loadOlderMessages(),
                              onRetryMessage: (clientId) => context
                                  .read<ServerCubit>()
                                  .retryMessage(clientId),
                              onInputChanged: (value) =>
                                  _onInputChanged(context, value),
                            ),
                          ),
                          const Divider(height: 1),
                          SizedBox(
                            height: 360,
                            child: _MembersPane(
                              sessionUserId: state.session?.user.id,
                              members: state.roleMembers,
                              presenceMembers: state.serverMembers,
                              canInviteMembers: state.canInviteMembers,
                              canManageRoles: state.canManageRoles,
                              submittingInvite: state.submittingInvite,
                              latestInvite: state.latestInvite,
                              inviteEmailController: _inviteEmailController,
                              inviteRole: _inviteRole,
                              onInviteRoleChanged: (value) {
                                setState(() {
                                  _inviteRole = value;
                                });
                              },
                              onInvite: () => _inviteMember(context),
                              onRoleChanged: (memberId, role) =>
                                  context.read<ServerCubit>().updateMemberRole(
                                        memberId: memberId,
                                        role: role,
                                      ),
                              onRemoveMember: (memberId) =>
                                  _confirmRemoveMember(context, memberId),
                              onTransferOwnership: (memberId) =>
                                  _confirmTransferOwnership(context, memberId),
                              onCreateInviteLink: () =>
                                  _showCreateInviteLinkDialog(context),
                            ),
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        _ServersPane(
                          servers: state.servers,
                          selectedServer: state.selectedServer,
                          loading: state.loading,
                          onSelect: (server) =>
                              context.read<ServerCubit>().selectServer(server),
                        ),
                        const VerticalDivider(width: 1),
                        _ChannelsPane(
                          channels: state.channels,
                          selectedChannel: state.selectedChannel,
                          canManageChannels: state.canManageChannels,
                          onCreateChannel: () =>
                              _showCreateChannelDialog(context),
                          onSelect: (channel) => context
                              .read<ServerCubit>()
                              .selectChannel(channel),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(
                          child: _MessagesPane(
                            selectedServer: state.selectedServer,
                            selectedChannel: state.selectedChannel,
                            messages: state.messages,
                            messageController: _messageController,
                            scrollController: _messageScrollController,
                            submitting: state.submittingMessage,
                            loadingOlderMessages: state.loadingOlderMessages,
                            hasMoreMessages: state.hasMoreMessages,
                            onlineMembers: state.onlineMembers,
                            typingMembers: state.typingMembers,
                            serverMembers: state.serverMembers,
                            onSend: () => _send(context),
                            onLoadOlder: () =>
                                context.read<ServerCubit>().loadOlderMessages(),
                            onRetryMessage: (clientId) => context
                                .read<ServerCubit>()
                                .retryMessage(clientId),
                            onInputChanged: (value) =>
                                _onInputChanged(context, value),
                          ),
                        ),
                        const VerticalDivider(width: 1),
                        _MembersPane(
                          sessionUserId: state.session?.user.id,
                          members: state.roleMembers,
                          presenceMembers: state.serverMembers,
                          canInviteMembers: state.canInviteMembers,
                          canManageRoles: state.canManageRoles,
                          submittingInvite: state.submittingInvite,
                          latestInvite: state.latestInvite,
                          inviteEmailController: _inviteEmailController,
                          inviteRole: _inviteRole,
                          onInviteRoleChanged: (value) {
                            setState(() {
                              _inviteRole = value;
                            });
                          },
                          onInvite: () => _inviteMember(context),
                          onRoleChanged: (memberId, role) =>
                              context.read<ServerCubit>().updateMemberRole(
                                    memberId: memberId,
                                    role: role,
                                  ),
                          onRemoveMember: (memberId) =>
                              _confirmRemoveMember(context, memberId),
                          onTransferOwnership: (memberId) =>
                              _confirmTransferOwnership(context, memberId),
                          onCreateInviteLink: () =>
                              _showCreateInviteLinkDialog(context),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showCreateServerDialog(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Create server'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Server name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (!context.mounted || name == null) return;
    await context.read<ServerCubit>().createServer(name);
  }

  Future<void> _showJoinByInviteDialog(BuildContext context) async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Join by invite'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Invite code or link',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: const Text('Join'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (!context.mounted || code == null) return;
    final normalized = _normalizeInviteCode(code);
    if (normalized.isEmpty) return;
    await context.read<ServerCubit>().joinByInviteCode(normalized);
  }

  Future<void> _showCreateInviteLinkDialog(BuildContext context) async {
    var role = 'member';
    final maxUsesController = TextEditingController(text: '0');
    final result = await showDialog<(String, int)>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create invite link'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: role,
                    items: const [
                      DropdownMenuItem(
                        value: 'member',
                        child: Text('member'),
                      ),
                      DropdownMenuItem(
                        value: 'admin',
                        child: Text('admin'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        role = value;
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Invite as',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const AppGap.v(height: 12),
                  TextField(
                    controller: maxUsesController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Max uses (0 = unlimited)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop((
                    role,
                    int.tryParse(maxUsesController.text.trim()) ?? 0,
                  )),
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
    maxUsesController.dispose();
    if (!context.mounted || result == null) return;
    await context.read<ServerCubit>().createInviteLink(
          role: result.$1,
          maxUses: result.$2,
        );
  }

  Future<void> _showCreateChannelDialog(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Create text channel'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Channel name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (!context.mounted || name == null) return;
    await context.read<ServerCubit>().createChannel(name);
  }

  Future<void> _inviteMember(BuildContext context) async {
    final email = _inviteEmailController.text.trim();
    if (email.isEmpty) return;
    await context.read<ServerCubit>().inviteMember(
          email: email,
          role: _inviteRole,
        );
    if (!mounted) return;
    _inviteEmailController.clear();
    setState(() {
      _inviteRole = 'member';
    });
  }

  Future<void> _confirmLeaveServer(BuildContext context) async {
    final cubit = context.read<ServerCubit>();
    final server = cubit.state.selectedServer;
    if (server == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave server'),
        content: Text('Leave "${server.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await cubit.leaveSelectedServer();
  }

  Future<void> _confirmRemoveMember(BuildContext context, int memberId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove member'),
        content: const Text('Remove this member from the server?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<ServerCubit>().removeMember(memberId);
  }

  Future<void> _confirmTransferOwnership(
      BuildContext context, int memberId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Transfer ownership'),
        content: const Text('Transfer server ownership to this member?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Transfer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<ServerCubit>().transferOwnership(memberId);
  }

  Future<void> _send(BuildContext context) async {
    final text = _messageController.text;
    if (text.trim().isEmpty) return;
    _messageController.clear();
    _typingStopTimer?.cancel();
    context.read<ServerCubit>().typingChanged('');
    await context.read<ServerCubit>().sendMessage(text);
  }

  void _onInputChanged(BuildContext context, String value) {
    context.read<ServerCubit>().typingChanged(value);
    _typingStopTimer?.cancel();
    if (value.trim().isEmpty) return;
    _typingStopTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      context.read<ServerCubit>().typingChanged('');
    });
  }

  String _normalizeInviteCode(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.last;
    }
    final slash = trimmed.lastIndexOf('/');
    if (slash >= 0 && slash + 1 < trimmed.length) {
      return trimmed.substring(slash + 1);
    }
    return trimmed;
  }
}

class _ServersPane extends StatelessWidget {
  const _ServersPane({
    required this.servers,
    required this.selectedServer,
    required this.loading,
    required this.onSelect,
  });

  final List<WorkspaceServer> servers;
  final WorkspaceServer? selectedServer;
  final bool loading;
  final ValueChanged<WorkspaceServer> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child:
                Text('Servers', style: Theme.of(context).textTheme.titleMedium),
          ),
          if (loading && servers.isEmpty)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (servers.isEmpty)
            const Expanded(
              child:
                  Center(child: Text('No servers yet. Create your first one.')),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: servers.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final server = servers[index];
                  return ListTile(
                    selected: selectedServer?.id == server.id,
                    title: Text(server.name),
                    subtitle: Text(
                      server.description.isEmpty
                          ? 'role: ${server.memberRole}'
                          : '${server.description}\nrole: ${server.memberRole}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: _UnreadBadge(count: server.unreadCount),
                    onTap: () => onSelect(server),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ChannelsPane extends StatelessWidget {
  const _ChannelsPane({
    required this.channels,
    required this.selectedChannel,
    required this.canManageChannels,
    required this.onCreateChannel,
    required this.onSelect,
  });

  final List<WorkspaceChannel> channels;
  final WorkspaceChannel? selectedChannel;
  final bool canManageChannels;
  final VoidCallback onCreateChannel;
  final ValueChanged<WorkspaceChannel> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Channels',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: canManageChannels ? onCreateChannel : null,
                  icon: const Icon(Icons.add),
                  tooltip: canManageChannels
                      ? 'Create channel'
                      : 'Channel creation requires owner/admin permission',
                ),
              ],
            ),
          ),
          Expanded(
            child: channels.isEmpty
                ? const Center(child: Text('Select or create a server first.'))
                : ListView.separated(
                    itemCount: channels.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final channel = channels[index];
                      return ListTile(
                        selected: selectedChannel?.id == channel.id,
                        title: Text(
                          '${channel.kind == 'text' ? '#' : 'V'} ${channel.name}',
                        ),
                        subtitle:
                            channel.topic.isEmpty ? null : Text(channel.topic),
                        trailing: channel.isText
                            ? _UnreadBadge(count: channel.unreadCount)
                            : null,
                        onTap: () => onSelect(channel),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _MessagesPane extends StatelessWidget {
  const _MessagesPane({
    required this.selectedServer,
    required this.selectedChannel,
    required this.messages,
    required this.messageController,
    required this.scrollController,
    required this.submitting,
    required this.loadingOlderMessages,
    required this.hasMoreMessages,
    required this.onlineMembers,
    required this.typingMembers,
    required this.serverMembers,
    required this.onSend,
    required this.onLoadOlder,
    required this.onRetryMessage,
    required this.onInputChanged,
  });

  final WorkspaceServer? selectedServer;
  final WorkspaceChannel? selectedChannel;
  final List<WorkspaceMessage> messages;
  final TextEditingController messageController;
  final ScrollController scrollController;
  final bool submitting;
  final bool loadingOlderMessages;
  final bool hasMoreMessages;
  final List<WorkspaceMember> onlineMembers;
  final List<WorkspaceMember> typingMembers;
  final List<WorkspaceMember> serverMembers;
  final VoidCallback onSend;
  final VoidCallback onLoadOlder;
  final ValueChanged<String> onRetryMessage;
  final ValueChanged<String> onInputChanged;

  @override
  Widget build(BuildContext context) {
    final channel = selectedChannel;
    if (selectedServer == null) {
      return const Center(
        child: Text('Create a server to start building the workspace.'),
      );
    }
    if (channel == null) {
      return const Center(child: Text('Pick a channel to view its history.'));
    }
    if (!channel.isText) {
      return Center(
        child: Text(
          'Voice channel "${channel.name}" is reserved for the next phase.',
        ),
      );
    }

    final serverOnline = serverMembers.where((item) => item.online).toList();
    final serverRecent = [...serverMembers]
      ..sort((a, b) => b.lastActive.compareTo(a.lastActive));
    final recentNames = serverRecent.take(3).map((item) {
      final time = DateFormat('HH:mm').format(item.lastActive.toLocal());
      return '${item.displayName} ($time)';
    }).join(', ');
    final onlineText = onlineMembers.isEmpty
        ? 'No one is online in this channel yet.'
        : 'Channel online: ${onlineMembers.map((item) => item.displayName).join(', ')}';
    final serverPresenceText = serverOnline.isEmpty
        ? 'Server online: none'
        : 'Server online: ${serverOnline.map((item) => item.displayName).join(', ')}';
    final recentText = recentNames.isEmpty
        ? 'Recent activity: none yet'
        : 'Recent activity: $recentNames';
    final typingText = typingMembers.isEmpty
        ? null
        : '${typingMembers.map((item) => item.displayName).join(', ')} ${typingMembers.length == 1 ? 'is' : 'are'} typing...';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '# ${channel.name}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (channel.topic.isNotEmpty) ...[
            const AppGap.v(height: 6),
            Text(channel.topic),
          ],
          const AppGap.v(height: 8),
          Text(serverPresenceText,
              style: Theme.of(context).textTheme.bodySmall),
          const AppGap.v(height: 4),
          Text(recentText, style: Theme.of(context).textTheme.bodySmall),
          const AppGap.v(height: 4),
          Text(onlineText, style: Theme.of(context).textTheme.bodySmall),
          const AppGap.v(height: 16),
          if (hasMoreMessages || loadingOlderMessages) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: loadingOlderMessages ? null : onLoadOlder,
                child: Text(
                  loadingOlderMessages ? 'Loading...' : 'Load older messages',
                ),
              ),
            ),
            const AppGap.v(height: 12),
          ],
          Expanded(
            child: messages.isEmpty
                ? const Center(
                    child: Text('No messages yet. Send the first one.'),
                  )
                : ListView.separated(
                    controller: scrollController,
                    itemCount: messages.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      return _MessageTile(
                        message: message,
                        onRetry:
                            message.status == WorkspaceMessageStatus.failed &&
                                    message.clientId != null
                                ? () => onRetryMessage(message.clientId!)
                                : null,
                      );
                    },
                  ),
          ),
          if (typingText != null) ...[
            const AppGap.v(height: 8),
            Text(typingText, style: Theme.of(context).textTheme.bodySmall),
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
                    hintText: 'Message #${channel.name}',
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

class _MembersPane extends StatelessWidget {
  const _MembersPane({
    required this.sessionUserId,
    required this.members,
    required this.presenceMembers,
    required this.canInviteMembers,
    required this.canManageRoles,
    required this.submittingInvite,
    required this.latestInvite,
    required this.inviteEmailController,
    required this.inviteRole,
    required this.onInviteRoleChanged,
    required this.onInvite,
    required this.onRoleChanged,
    required this.onRemoveMember,
    required this.onTransferOwnership,
    required this.onCreateInviteLink,
  });

  final int? sessionUserId;
  final List<WorkspaceServerRoleMember> members;
  final List<WorkspaceMember> presenceMembers;
  final bool canInviteMembers;
  final bool canManageRoles;
  final bool submittingInvite;
  final WorkspaceServerInvite? latestInvite;
  final TextEditingController inviteEmailController;
  final String inviteRole;
  final ValueChanged<String> onInviteRoleChanged;
  final VoidCallback onInvite;
  final void Function(int memberId, String role) onRoleChanged;
  final ValueChanged<int> onRemoveMember;
  final ValueChanged<int> onTransferOwnership;
  final VoidCallback onCreateInviteLink;

  @override
  Widget build(BuildContext context) {
    final onlineIds = presenceMembers
        .where((item) => item.online)
        .map((item) => item.userId)
        .toSet();

    // 略宽于 320，避免 ListTile + Outline 下拉在默认 padding 下横向溢出几条像素。
    return SizedBox(
      width: 352,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Roles & Members',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (canInviteMembers)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  TextField(
                    controller: inviteEmailController,
                    decoration: const InputDecoration(
                      labelText: 'Invite by email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const AppGap.v(height: 8),
                  DropdownButtonFormField<String>(
                    value: inviteRole,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: 'member',
                        child: Text('member'),
                      ),
                      DropdownMenuItem(
                        value: 'admin',
                        child: Text('admin'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        onInviteRoleChanged(value);
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Invite as',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const AppGap.v(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: submittingInvite ? null : onInvite,
                      child: Text(submittingInvite ? 'Inviting...' : 'Invite'),
                    ),
                  ),
                  const AppGap.v(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: onCreateInviteLink,
                      icon: const Icon(Icons.link),
                      label: const Text('Create invite link'),
                    ),
                  ),
                  if (latestInvite != null) ...[
                    const AppGap.v(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border:
                            Border.all(color: Theme.of(context).dividerColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Latest invite',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const AppGap.v(height: 6),
                          SelectableText('Code: ${latestInvite!.code}'),
                          const AppGap.v(height: 4),
                          SelectableText('Path: ${latestInvite!.inviteLink}'),
                          const AppGap.v(height: 4),
                          Text(
                            latestInvite!.maxUses > 0
                                ? 'Role: ${latestInvite!.role} · uses ${latestInvite!.useCount}/${latestInvite!.maxUses}'
                                : 'Role: ${latestInvite!.role} · unlimited uses',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          const AppGap.v(height: 12),
          Expanded(
            child: members.isEmpty
                ? const Center(child: Text('No members yet.'))
                : ListView.separated(
                    itemCount: members.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final member = members[index];
                      final online = onlineIds.contains(member.userId);
                      final canEditRole = canManageRoles &&
                          member.role != 'owner' &&
                          member.userId != sessionUserId;
                      final canRemoveMember = canManageRoles &&
                          member.role != 'owner' &&
                          member.userId != sessionUserId;
                      final canTransferOwnership = canManageRoles &&
                          member.role != 'owner' &&
                          member.userId != sessionUserId;
                      // 不用 ListTile.trailing：窄宽时 Flutter 会把 trailing 压到 ~50px，
                      // DropdownButtonFormField 必溢出。改用 Row + 固定角色列宽。
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    member.displayName,
                                    style:
                                        Theme.of(context).textTheme.titleSmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const AppGap.v(height: 4),
                                  Text(
                                    '${member.email}\njoined ${DateFormat('MM-dd').format(member.joinedAt.toLocal())} · ${online ? 'online' : 'offline'}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 118,
                              child: member.role == 'owner'
                                  ? const InputDecorator(
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 10,
                                        ),
                                      ),
                                      child: Text('owner'),
                                    )
                                  : DropdownButtonFormField<String>(
                                      value: member.role == 'admin'
                                          ? 'admin'
                                          : 'member',
                                      isDense: true,
                                      isExpanded: true,
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'admin',
                                          child: Text('admin'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'member',
                                          child: Text('member'),
                                        ),
                                      ],
                                      onChanged: canEditRole
                                          ? (value) {
                                              if (value != null) {
                                                onRoleChanged(
                                                  member.userId,
                                                  value,
                                                );
                                              }
                                            }
                                          : null,
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 8,
                                        ),
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              children: [
                                IconButton(
                                  onPressed: canTransferOwnership
                                      ? () => onTransferOwnership(member.userId)
                                      : null,
                                  icon: const Icon(Icons.workspace_premium),
                                  tooltip: 'Transfer ownership',
                                ),
                                IconButton(
                                  onPressed: canRemoveMember
                                      ? () => onRemoveMember(member.userId)
                                      : null,
                                  icon: const Icon(Icons.person_remove),
                                  tooltip: 'Remove member',
                                ),
                              ],
                            ),
                          ],
                        ),
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
    if (count <= 0) {
      return const SizedBox.shrink();
    }

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

class _MessageTile extends StatelessWidget {
  const _MessageTile({required this.message, this.onRetry});

  final WorkspaceMessage message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  message.senderDisplayName,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const AppGap.h(width: 8),
                Text(
                  DateFormat('MM-dd HH:mm').format(message.createdAt.toLocal()),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (message.status != WorkspaceMessageStatus.sent) ...[
                  const AppGap.h(width: 8),
                  Text(
                    message.status == WorkspaceMessageStatus.sending
                        ? 'Sending'
                        : 'Failed',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: message.status == WorkspaceMessageStatus.failed
                              ? Theme.of(context).colorScheme.error
                              : null,
                        ),
                  ),
                ],
              ],
            ),
            const AppGap.v(height: 8),
            Text(message.content),
            if (message.status == WorkspaceMessageStatus.failed &&
                onRetry != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onRetry,
                  child: const Text('Retry send'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
