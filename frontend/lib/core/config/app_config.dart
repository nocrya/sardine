class AppConfig {
  const AppConfig._();

  static const String environment = String.fromEnvironment(
    'SARDINE_ENV',
    defaultValue: 'development',
  );

  static const String apiBaseUrl = String.fromEnvironment(
    'SARDINE_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8080',
  );

  static bool get isDevelopment => environment == 'development';
}
