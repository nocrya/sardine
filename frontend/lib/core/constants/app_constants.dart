import 'package:sardine/core/config/app_config.dart';

/// 应用级常量：API 基址、版本号、超时等，后续可补充。
class AppConstants {
  AppConstants._();

  /// 后端基址，开发阶段通过 `--dart-define=SARDINE_API_BASE_URL=...` 覆盖。
  static const String defaultApiBaseUrl = AppConfig.apiBaseUrl;

  static Uri websocketUri(String token) {
    final apiUri = Uri.parse(defaultApiBaseUrl);
    final normalizedPath = apiUri.path == '/'
        ? ''
        : (apiUri.path.endsWith('/')
            ? apiUri.path.substring(0, apiUri.path.length - 1)
            : apiUri.path);

    return Uri(
      scheme: apiUri.scheme == 'https' ? 'wss' : 'ws',
      host: apiUri.host,
      port: apiUri.hasPort ? apiUri.port : null,
      path: '$normalizedPath/ws',
      queryParameters: {'token': token},
    );
  }
}
