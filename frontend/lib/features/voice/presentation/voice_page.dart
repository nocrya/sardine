import 'package:flutter/material.dart';
import 'package:sardine/shared/widgets/app_gap.dart';

/// 语音/房间/ LiveKit 相关 UI 占位。
class VoicePage extends StatelessWidget {
  const VoicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Voice Lab')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              '语音能力暂时保留占位，等文本 IM 闭环稳定后再接 LiveKit。',
              style: TextStyle(fontSize: 16),
            ),
            AppGap.v(height: 16),
            Text('这里后续承载房间状态、成员列表和麦克风控制。'),
          ],
        ),
      ),
    );
  }
}
