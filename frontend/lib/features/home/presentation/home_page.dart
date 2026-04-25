import 'package:flutter/material.dart';
import 'package:sardine/core/config/app_config.dart';
import 'package:sardine/core/router/app_router.dart';
import 'package:sardine/shared/widgets/app_gap.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final cards = [
      (
        title: 'Authentication',
        subtitle: '登录、注册和登录态恢复入口',
        route: AppRouter.auth,
      ),
      (
        title: 'Server Workspace',
        subtitle: '后续承载 server、channel、message 三栏布局',
        route: AppRouter.server,
      ),
      (
        title: 'Direct Messages',
        subtitle: '最小可用私聊会话和消息列表',
        route: AppRouter.directMessage,
      ),
      (
        title: 'Voice Lab',
        subtitle: '后续承载 LiveKit 房间和语音状态面板',
        route: AppRouter.voice,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Sardine')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            '第一阶段已经补齐基础路由和环境配置。',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const AppGap.v(height: 12),
          Text(
            'Current backend: ${AppConfig.apiBaseUrl}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const AppGap.v(height: 24),
          for (final card in cards) ...[
            _EntryCard(
              title: card.title,
              subtitle: card.subtitle,
              onTap: () => Navigator.of(context).pushNamed(card.route),
            ),
            const AppGap.v(height: 16),
          ],
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const AppGap.v(height: 8),
              Text(subtitle),
            ],
          ),
        ),
      ),
    );
  }
}
