import '../../../core/network/api_client.dart';

class MicroappSession {
  const MicroappSession({required this.token, required this.url, required this.expiresIn, required this.allowedNavigation, required this.context});
  factory MicroappSession.fromJson(Map<String, dynamic> j) => MicroappSession(
        token: j['token'] as String,
        url: j['url'] as String,
        expiresIn: (j['expiresIn'] as num).toInt(),
        allowedNavigation: ((j['allowedNavigation'] as List?) ?? const []).map((e) => '$e').toList(),
        context: Map<String, dynamic>.from((j['context'] as Map?) ?? const {}),
      );
  final String token, url;
  final int expiresIn;
  final List<String> allowedNavigation;
  final Map<String, dynamic> context;
}

class MicroappsRepository {
  MicroappsRepository(this.api);
  final ApiClient api;

  /// Pide al BFF una sesión con token de alcance mínimo (audiencia = micro-app, scopes limitados).
  /// El access token principal nunca se entrega a código de terceros.
  Future<MicroappSession> createSession(String appId) async =>
      MicroappSession.fromJson(await api.post<Json>('/v1/microapps/$appId/session'));
}
