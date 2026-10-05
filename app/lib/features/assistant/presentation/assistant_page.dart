import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/deep_links.dart';
import '../../../app/di.dart';
import '../../../core/network/failures.dart';
import '../../../core/observability/telemetry.dart';
import '../../../design_system/tokens.dart';
import '../data/assistant_repository.dart';

class ChatMessage extends Equatable {
  const ChatMessage.user(this.text) : fromUser = true, reply = null, failed = false;
  const ChatMessage.bot(AssistantReply r) : fromUser = false, reply = r, text = '', failed = false;
  const ChatMessage.failed(this.text) : fromUser = true, reply = null, failed = true;
  final String text;
  final bool fromUser;
  final AssistantReply? reply;

  /// Mensaje del usuario que no llegó (sin red): se puede reenviar.
  final bool failed;
  @override
  List<Object?> get props => [text, fromUser, reply?.text, failed];
}

class AssistantState extends Equatable {
  const AssistantState({this.messages = const [], this.sending = false});
  final List<ChatMessage> messages;
  final bool sending;
  @override
  List<Object?> get props => [messages, sending];
}

class AssistantCubit extends Cubit<AssistantState> {
  AssistantCubit(this._repo, this._telemetry)
    : super(
        const AssistantState(
          messages: [
            ChatMessage.bot(
              AssistantReply(
                text: 'Hola, soy tu asistente. Puedo contarte tu saldo, analizar tus gastos o ayudarte a planificar.',
                suggestions: ['¿Cuál es mi saldo?', '¿En qué gasto más?', '¿Cómo puedo ahorrar más?'],
              ),
            ),
          ],
        ),
      );
  final AssistantRepository _repo;
  final Telemetry _telemetry;

  Future<void> send(String text, {bool isRetry = false}) async {
    final msg = text.trim();
    if (msg.isEmpty || state.sending) return;
    final base = isRetry ? state.messages.where((m) => !(m.failed && m.text == msg)).toList() : state.messages;
    emit(AssistantState(messages: [...base, ChatMessage.user(msg)], sending: true));
    try {
      final reply = await _repo.ask(msg);
      _telemetry.event('assistant_answered', {'source': reply.source});
      emit(AssistantState(messages: [...state.messages, ChatMessage.bot(reply)]));
    } on AppFailure {
      final withoutLast = state.messages.sublist(0, state.messages.length - 1);
      emit(AssistantState(messages: [...withoutLast, ChatMessage.failed(msg)]));
    }
  }
}

class AssistantPage extends StatelessWidget {
  const AssistantPage({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => AssistantCubit(sl<AssistantRepository>(), sl<Telemetry>()),
    child: const _AssistantView(),
  );
}

class _AssistantView extends StatefulWidget {
  const _AssistantView();
  @override
  State<_AssistantView> createState() => _AssistantViewState();
}

class _AssistantViewState extends State<_AssistantView> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([String? text]) {
    final t = text ?? _input.text;
    _input.clear();
    context.read<AssistantCubit>().send(t);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Asistente')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: BlocConsumer<AssistantCubit, AssistantState>(
                listener:
                    (_, __) => WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scroll.hasClients) {
                        _scroll.animateTo(
                          _scroll.position.maxScrollExtent,
                          duration: KMotion.medium,
                          curve: Curves.easeOut,
                        );
                      }
                    }),
                builder:
                    (context, s) => ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(KSpace.md),
                      itemCount: s.messages.length + (s.sending ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i == s.messages.length) {
                          return const Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(padding: EdgeInsets.all(8), child: Text('Escribiendo…')),
                          );
                        }
                        final m = s.messages[i];
                        if (m.fromUser) {
                          return Align(
                            alignment: Alignment.centerRight,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  padding: const EdgeInsets.all(12),
                                  constraints: const BoxConstraints(maxWidth: 300),
                                  decoration: BoxDecoration(
                                    color: scheme.primary,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(m.text, style: TextStyle(color: scheme.onPrimary)),
                                ),
                                if (m.failed)
                                  TextButton.icon(
                                    onPressed: () => context.read<AssistantCubit>().send(m.text, isRetry: true),
                                    icon: const Icon(Icons.refresh, size: 16),
                                    label: const Text('No se envió. Reintentar'),
                                  ),
                              ],
                            ),
                          );
                        }
                        final r = m.reply!;
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.all(12),
                                constraints: const BoxConstraints(maxWidth: 320),
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Semantics(liveRegion: i == s.messages.length - 1, child: Text(r.text)),
                              ),
                              if (r.actionDeeplink != null)
                                FilledButton.tonal(
                                  onPressed:
                                      () => sl<DeepLinks>().open(context, r.actionDeeplink!, source: 'assistant'),
                                  child: Text(r.actionLabel ?? 'Abrir'),
                                ),
                              if (i == s.messages.length - 1)
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    for (final sug in r.suggestions)
                                      ActionChip(label: Text(sug), onPressed: () => _send(sug)),
                                  ],
                                ),
                              if (r.source == 'llm')
                                Text(
                                  'Respuesta generada con IA a partir de datos agregados',
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                            ],
                          ),
                        );
                      },
                    ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(KSpace.sm),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('assistant_input'),
                      controller: _input,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(hintText: 'Escribe tu pregunta', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(tooltip: 'Enviar', onPressed: _send, icon: const Icon(Icons.send_rounded)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
