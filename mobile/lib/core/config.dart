class AppConfig {
  // Real phone example: --dart-define=API_BASE_URL=http://192.168.1.20:8000
  // Production example: --dart-define=API_BASE_URL=https://your-backend.com
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000', // Android emulator -> localhost
  );

  static const String apiKey = String.fromEnvironment('API_KEY', defaultValue: '');

  static const Duration requestTimeout = Duration(seconds: 30);
  static const Duration connectTimeout = Duration(seconds: 10);
}
