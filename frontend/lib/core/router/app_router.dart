import 'package:flutter/material.dart';
import 'package:sardine/features/auth/presentation/auth_page.dart';
import 'package:sardine/features/direct_message/presentation/direct_message_page.dart';
import 'package:sardine/features/home/presentation/home_page.dart';
import 'package:sardine/features/invite/presentation/invite_page.dart';
import 'package:sardine/features/server/presentation/server_page.dart';
import 'package:sardine/features/voice/presentation/voice_page.dart';

class AppRouter {
  const AppRouter._();

  static const String home = '/';
  static const String auth = '/auth';
  static const String directMessage = '/direct-message';
  static const String invite = '/invite';
  static const String server = '/server';
  static const String voice = '/voice';

  static Map<String, WidgetBuilder> get routes => {
        home: (_) => const HomePage(),
        auth: (_) => const AuthPage(),
        directMessage: (_) => const DirectMessagePage(),
        server: (_) => const ServerPage(),
        voice: (_) => const VoicePage(),
      };

  static String invitePath(String code) => '$invite/$code';

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final name = settings.name ?? '';
    if (name == invite) {
      return MaterialPageRoute<void>(
        builder: (_) => const InvitePage(),
        settings: settings,
      );
    }
    if (name.startsWith('$invite/')) {
      final uri = Uri.parse(name);
      final code = uri.pathSegments.length >= 2 ? uri.pathSegments[1] : '';
      return MaterialPageRoute<void>(
        builder: (_) => InvitePage(initialCode: code),
        settings: settings,
      );
    }
    return null;
  }
}
