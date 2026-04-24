import 'package:flutter/material.dart';

/// 应用主题，后续可拆分为颜色、字重、圆角等。
class AppTheme {
  AppTheme._();

  static final ThemeData light = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D9488)),
    useMaterial3: true,
  );
}
