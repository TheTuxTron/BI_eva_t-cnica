import '../../../core/network/api_client.dart';

class AssistantReply {
  const AssistantReply({
    required this.text,
    this.suggestions = const [],
    this.actionLabel,
    this.actionDeeplink,
    this.source = 'rules',
  });
  factory AssistantReply.fromJson(Map<String, dynamic> j) {
    final action = j['action'] is Map ? Map<String, dynamic>.from(j['action'] as Map) : null;
    return AssistantReply(
      text: j['reply'] as String,
      suggestions: ((j['suggestions'] as List?) ?? const []).map((e) => '$e').toList(),
      actionLabel: action?['label'] as String?,
      actionDeeplink: action?['deeplink'] as String?,
      source: (j['source'] as String?) ?? 'rules',
    );
  }
  final String text;
  final List<String> suggestions;
  final String? actionLabel;
  final String? actionDeeplink;

  /// 'llm' | 'rules' | 'rules-fallback': transparencia sobre quién respondió.
  final String source;
}

class AssistantRepository {
  AssistantRepository(this.api);
  final ApiClient api;

  Future<AssistantReply> ask(String message) async =>
      AssistantReply.fromJson(await api.post<Json>('/v1/assistant/messages', body: {'message': message}));
}
