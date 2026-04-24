import 'package:flutter/material.dart';
import 'package:sardine/features/auth/presentation/auth_page.dart';
import 'package:sardine/features/home/presentation/home_page.dart';
import 'package:sardine/features/server/presentation/server_page.dart';
import 'package:sardine/features/voice/presentation/voice_page.dart';

class AppRouter {
  const AppRouter._();

  static const String home = '/';
  static const String auth = '/auth';
  static const String server = '/server';
  static const String voice = '/voice';

  static Map<String, WidgetBuilder> get routes => {
        home: (_) => const HomePage(),
        auth: (_) => const AuthPage(),
        server: (_) => const ServerPage(),
        voice: (_) => const VoicePage(),
      };
}
