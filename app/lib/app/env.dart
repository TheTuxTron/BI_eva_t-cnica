/// Configuración por entorno inyectada con --dart-define (nunca secretos de backend en el binario).
class AppEnv {
  const AppEnv({
    required this.apiBaseUrl,
    required this.flavor,
    this.sentryDsn = '',
    this.adminKey = '',
    this.enableDevTools = false,
    this.pollingInterval = const Duration(seconds: 30),
  });

  factory AppEnv.fromDefines() => const AppEnv(
    apiBaseUrl: String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8080'),
    flavor: String.fromEnvironment('FLAVOR', defaultValue: 'dev'),
    sentryDsn: String.fromEnvironment('SENTRY_DSN'),
    adminKey: String.fromEnvironment('ADMIN_KEY', defaultValue: 'dev-admin-key'),
    enableDevTools: bool.fromEnvironment('DEV_TOOLS', defaultValue: true),
  );

  final String apiBaseUrl;
  final String flavor;
  final String sentryDsn;

  /// Solo para el panel de diagnóstico de demo/QA (inyección de fallas). Nunca en producción.
  final String adminKey;
  final bool enableDevTools;
  final Duration pollingInterval;

  bool get isProduction => flavor == 'prod';
}
