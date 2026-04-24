import 'package:flutter/material.dart';
import 'package:sardine/shared/widgets/app_gap.dart';

/// 服务器/房间列表等（命名依产品为准）占位。
class ServerPage extends StatelessWidget {
  const ServerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Server Workspace')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              '下一步会在这里落三栏结构：server 列表、channel 列表、消息区。',
              style: TextStyle(fontSize: 16),
            ),
            AppGap.v(height: 16),
            Text('当前阶段目标：先把 app 导航、后端配置和数据库接入打通。'),
          ],
        ),
      ),
    );
  }
}
