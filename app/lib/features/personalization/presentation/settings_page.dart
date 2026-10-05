import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di.dart';
import '../../../app/env.dart';
import '../../../core/cache/resource.dart';
import '../../../core/network/failures.dart';
import '../../../design_system/theme_cubit.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/widgets.dart';
import '../../auth/presentation/session_cubit.dart';
import '../../notifications/data/push_service.dart';
import '../data/experience_repository.dart';
import 'home_experience_cubit.dart';

class PreferencesCubit extends Cubit<Resource<ProfileInfo>> {
  PreferencesCubit(this._repo) : super(const Resource.loading());
  final ExperienceRepository _repo;
  StreamSubscription<Resource<ProfileInfo>>? _sub;

  void load() {
    _sub?.cancel();
    _sub = _repo.watchProfile().listen(emit);
  }

  /// Actualización optimista: se aplica al instante y se revierte si el servidor falla.
  Future<AppFailure?> update(UserPreferences Function(UserPreferences) change) async {
    final current = state.data;
    if (current == null) return null;
    final next = change(current.preferences);
    emit(state.copyWith(data: _with(current, next)));
    try {
      final saved = await _repo.updatePreferences(next);
      emit(state.copyWith(data: _with(current, saved), clearError: true));
      return null;
    } on AppFailure catch (f) {
      emit(state.copyWith(data: current));
      return f;
    }
  }

  ProfileInfo _with(ProfileInfo p, UserPreferences prefs) =>
      ProfileInfo(firstName: p.firstName, lastName: p.lastName, email: p.email, segment: p.segment, preferences: prefs);

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(create: (_) => PreferencesCubit(sl<ExperienceRepository>())..load(), child: const _SettingsView());
}

class _SettingsView extends StatelessWidget {
  const _SettingsView();

  static const _toggleable = [
    ('insights', 'Consejos sobre tus gastos'),
    ('fx', 'Tipo de cambio'),
    ('microapp_simulator', 'Simulador financiero'),
    ('quick_actions', 'Accesos rápidos'),
  ];

  Future<void> _save(BuildContext context, UserPreferences Function(UserPreferences) change) async {
    final messenger = ScaffoldMessenger.of(context);
    final home = context.read<HomeExperienceCubit>();
    final failure = await context.read<PreferencesCubit>().update(change);
    if (failure != null) {
      messenger.showSnackBar(SnackBar(content: Text('No se guardó el cambio: ${failure.message}')));
    } else {
      unawaited(home.load());
    }
  }

  @override
  Widget build(BuildContext context) {
    final env = sl<AppEnv>();
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil y ajustes')),
      body: BlocBuilder<PreferencesCubit, Resource<ProfileInfo>>(
        builder: (context, r) {
          final p = r.data;
          final reasons = context.select((HomeExperienceCubit c) => c.state.data?.reasons ?? const <String>[]);
          final segment = context.select((HomeExperienceCubit c) => c.state.data?.segment);
          return ListView(padding: const EdgeInsets.all(KSpace.md), children: [
            if (p == null && r.isFatal) ErrorView(failure: r.error!, onRetry: () => context.read<PreferencesCubit>().load()),
            if (p == null && !r.isFatal) const Skeleton(height: 64),
            if (p != null) ...[
              KCard(
                child: Row(children: [
                  CircleAvatar(radius: 26, child: Text(p.firstName.characters.first)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${p.firstName} ${p.lastName}', style: Theme.of(context).textTheme.titleMedium),
                      Text(p.email, style: Theme.of(context).textTheme.bodySmall),
                    ]),
                  ),
                  if (segment != null) Chip(label: Text(_segmentLabel(segment))),
                ]),
              ),
              const SizedBox(height: KSpace.lg),
              const SectionTitle('Apariencia'),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'system', label: Text('Sistema'), icon: Icon(Icons.brightness_auto)),
                  ButtonSegment(value: 'light', label: Text('Claro'), icon: Icon(Icons.light_mode_outlined)),
                  ButtonSegment(value: 'dark', label: Text('Oscuro'), icon: Icon(Icons.dark_mode_outlined)),
                ],
                selected: {p.preferences.theme},
                onSelectionChanged: (v) {
                  context.read<ThemeCubit>().setMode(switch (v.first) { 'light' => ThemeMode.light, 'dark' => ThemeMode.dark, _ => ThemeMode.system });
                  _save(context, (x) => x.copyWith(theme: v.first));
                },
              ),
              const SizedBox(height: KSpace.lg),
              const SectionTitle('Personaliza tu inicio'),
              KCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  SwitchListTile(
                    title: const Text('Mostrar saldos al abrir'),
                    value: p.preferences.balanceVisible,
                    onChanged: (v) => _save(context, (x) => x.copyWith(balanceVisible: v)),
                  ),
                  for (final (id, label) in _toggleable)
                    SwitchListTile(
                      key: Key('pref_$id'),
                      title: Text(label),
                      value: !p.preferences.hiddenSections.contains(id),
                      onChanged: (show) => _save(context, (x) {
                        final hidden = {...x.hiddenSections};
                        if (show) {
                          hidden.remove(id);
                        } else {
                          hidden.add(id);
                        }
                        return x.copyWith(hiddenSections: hidden.toList());
                      }),
                    ),
                ]),
              ),
              if (reasons.isNotEmpty) ...[
                const SizedBox(height: KSpace.lg),
                const SectionTitle('¿Por qué veo este inicio?'),
                KCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (final reason in reasons)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Icon(Icons.lightbulb_outline, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(reason)),
                        ]),
                      ),
                  ]),
                ),
              ],
              const SizedBox(height: KSpace.lg),
              const SectionTitle('Notificaciones'),
              KCard(
                padding: EdgeInsets.zero,
                child: SwitchListTile(
                  title: const Text('Avisos de movimientos'),
                  subtitle: Text(sl<PushService>().channelDescription),
                  value: p.preferences.notificationsEnabled,
                  onChanged: (v) => _save(context, (x) => x.copyWith(notificationsEnabled: v)),
                ),
              ),
            ],
            const SizedBox(height: KSpace.lg),
            if (env.enableDevTools)
              ListTile(
                key: const Key('open_diagnostics'),
                leading: const Icon(Icons.bug_report_outlined),
                title: const Text('Diagnóstico y resiliencia'),
                subtitle: const Text('Simular latencia, errores y caídas'),
                onTap: () => context.push('/diagnostics'),
              ),
            ListTile(
              key: const Key('logout'),
              leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
              title: Text('Cerrar sesión', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () => context.read<SessionCubit>().logout(),
            ),
            Center(child: Text('Kinti ${env.flavor} · v1.0.0', style: Theme.of(context).textTheme.bodySmall)),
          ]);
        },
      ),
    );
  }

  static String _segmentLabel(String s) => switch (s) { 'joven' => 'Joven', 'premium' => 'Premium', _ => 'Clásico' };
}

