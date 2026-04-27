import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:sardine/core/di/dependency_injection.dart';
import 'package:sardine/core/router/app_router.dart';
import 'package:sardine/features/auth/data/auth_remote_datasource.dart';
import 'package:sardine/features/invite/data/invite_models.dart';
import 'package:sardine/features/server/data/server_remote_datasource.dart';
import 'package:sardine/shared/widgets/app_gap.dart';

class InvitePage extends StatefulWidget {
  const InvitePage({
    super.key,
    this.initialCode = '',
  });

  final String initialCode;

  @override
  State<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends State<InvitePage> {
  late final TextEditingController _codeController;
  late final ServerRemoteDataSource _serverDataSource;
  late final AuthRemoteDataSource _authDataSource;
  InvitePreview? _preview;
  String? _errorMessage;
  String? _feedbackMessage;
  bool _loading = false;
  bool _joining = false;

  bool get _authenticated => _authDataSource.loadSession() != null;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.initialCode);
    _serverDataSource = getIt<ServerRemoteDataSource>();
    _authDataSource = getIt<AuthRemoteDataSource>();
    if (widget.initialCode.trim().isNotEmpty) {
      _loadPreview(widget.initialCode);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;

    return Scaffold(
      appBar: AppBar(title: const Text('Server Invite')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Join a workspace by invite link',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const AppGap.v(height: 12),
          TextField(
            controller: _codeController,
            enabled: !_loading && !_joining,
            decoration: const InputDecoration(
              labelText: 'Invite code or /invite path',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _previewCode(),
          ),
          const AppGap.v(height: 12),
          Row(
            children: [
              FilledButton(
                onPressed: _loading || _joining ? null : _previewCode,
                child: Text(_loading ? 'Loading...' : 'Preview invite'),
              ),
              const AppGap.h(width: 12),
              OutlinedButton(
                onPressed: _authenticated
                    ? null
                    : () => Navigator.of(context).pushNamed(
                          AppRouter.auth,
                          arguments: _normalizedCode,
                        ),
                child: const Text('Login / Register'),
              ),
            ],
          ),
          const AppGap.v(height: 16),
          if (_errorMessage != null) ...[
            Text(
              _errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const AppGap.v(height: 12),
          ],
          if (_feedbackMessage != null) ...[
            Text(
              _feedbackMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
            const AppGap.v(height: 12),
          ],
          if (preview != null) ...[
            _InvitePreviewCard(
              preview: preview,
              authenticated: _authenticated,
              joining: _joining,
              onJoin: preview.expired || !_authenticated ? null : _joinInvite,
              onAuth: !_authenticated
                  ? () => Navigator.of(context).pushNamed(
                        AppRouter.auth,
                        arguments: preview.code,
                      )
                  : null,
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Paste an invite link or code to preview the target server before joining.',
              ),
            ),
          ],
        ],
      ),
    );
  }

  String get _normalizedCode {
    final raw = _codeController.text.trim();
    if (raw.isEmpty) {
      return '';
    }
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.last;
    }
    final slash = raw.lastIndexOf('/');
    if (slash >= 0 && slash + 1 < raw.length) {
      return raw.substring(slash + 1);
    }
    return raw;
  }

  Future<void> _previewCode() async {
    final code = _normalizedCode;
    if (code.isEmpty) {
      setState(() {
        _errorMessage = 'Invite code is required';
        _feedbackMessage = null;
        _preview = null;
      });
      return;
    }
    await _loadPreview(code);
  }

  Future<void> _loadPreview(String code) async {
    setState(() {
      _loading = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });

    try {
      final preview = await _serverDataSource.previewInvite(code);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _preview = preview;
        _codeController.text = preview.code;
      });
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _preview = null;
        _errorMessage = _messageFrom(error);
      });
    }
  }

  Future<void> _joinInvite() async {
    final preview = _preview;
    if (preview == null || preview.expired) {
      return;
    }

    setState(() {
      _joining = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });

    try {
      await _serverDataSource.joinByInviteCode(preview.code);
      if (!mounted) return;
      setState(() {
        _joining = false;
        _feedbackMessage = 'Joined ${preview.serverName}';
      });
      Navigator.of(context).pushReplacementNamed(AppRouter.server);
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _joining = false;
        _errorMessage = _messageFrom(error);
      });
    }
  }

  String _messageFrom(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic> && data['error'] is String) {
      return data['error'] as String;
    }
    return error.message ?? 'Invite request failed';
  }
}

class _InvitePreviewCard extends StatelessWidget {
  const _InvitePreviewCard({
    required this.preview,
    required this.authenticated,
    required this.joining,
    required this.onJoin,
    required this.onAuth,
  });

  final InvitePreview preview;
  final bool authenticated;
  final bool joining;
  final VoidCallback? onJoin;
  final VoidCallback? onAuth;

  @override
  Widget build(BuildContext context) {
    final subtitle = preview.serverDescription.trim().isEmpty
        ? 'A Sardine workspace'
        : preview.serverDescription;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            preview.serverName,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const AppGap.v(height: 8),
          Text(subtitle),
          const AppGap.v(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(label: 'Role', value: preview.role),
              _InfoChip(label: 'Members', value: '${preview.memberCount}'),
              _InfoChip(label: 'Channels', value: '${preview.channelCount}'),
              _InfoChip(
                label: 'Uses',
                value: preview.maxUses > 0
                    ? '${preview.useCount}/${preview.maxUses}'
                    : '${preview.useCount}/unlimited',
              ),
            ],
          ),
          const AppGap.v(height: 16),
          SelectableText('Link path: ${preview.inviteLink}'),
          const AppGap.v(height: 12),
          if (preview.expired)
            Text(
              'This invite is expired or exhausted.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            )
          else if (!authenticated)
            const Text('Sign in first, then come back to join this server.')
          else
            const Text('You are signed in and can join this server now.'),
          const AppGap.v(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton(
                onPressed: onJoin,
                child: Text(joining ? 'Joining...' : 'Join server'),
              ),
              if (!authenticated)
                OutlinedButton(
                  onPressed: onAuth,
                  child: const Text('Go to auth'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text('$label: $value'),
      ),
    );
  }
}
