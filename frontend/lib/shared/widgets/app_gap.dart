import 'package:flutter/material.dart';

/// 占位：布局间距/常用间距 Widget，可逐步替换为设计规范。
class AppGap extends StatelessWidget {
  const AppGap.h({this.width, super.key})
      : h = true,
        height = null;
  const AppGap.v({this.height, super.key})
      : h = false,
        width = null;

  final bool h;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    if (h) return SizedBox(width: width);
    return SizedBox(height: height);
  }
}
