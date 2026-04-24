import 'package:flutter/material.dart';
import 'package:sardine/core/config/app_config.dart';
import 'package:sardine/core/router/app_router.dart';
import 'package:sardine/shared/theme/app_theme.dart';

/// 根 [MaterialApp]，后续可包裹 Bloc 的全局 [BlocProvider] 等。
class SardineApp extends StatelessWidget {
  const SardineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sardine',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: AppRouter.home,
      routes: AppRouter.routes,
      builder: (context, child) {
        return Banner(
          message: AppConfig.environment,
          location: BannerLocation.topEnd,
          color: AppConfig.isDevelopment
              ? const Color(0xFF0D9488)
              : const Color(0xFFB45309),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
