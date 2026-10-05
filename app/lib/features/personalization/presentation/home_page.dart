import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di.dart';
import '../../../core/cache/resource.dart';
import '../../../core/observability/telemetry.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/widgets.dart';
import '../../../sdui/sdui_models.dart';
import '../../../sdui/sdui_registry.dart';
import '../../../sdui/sdui_renderer.dart';
import '../../accounts/presentation/accounts_cubit.dart';
import '../../fx/presentation/fx_cubit.dart';
import '../../notifications/presentation/notifications_cubit.dart';
import 'home_experience_cubit.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _refresh(BuildContext context) async {
    sl<Telemetry>().event('home_pull_to_refresh');
    await Future.wait([
      context.read<HomeExperienceCubit>().load(),
      context.read<AccountsCubit>().load(),
      context.read<FxCubit>().load(),
      context.read<NotificationsCubit>().refresh(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final unread = context.select((NotificationsCubit c) => c.state.unread);
    return Scaffold(
      appBar: AppBar(
        title: const KintiLogo(size: 28),
        actions: [
          IconButton(
            key: const Key('home_assistant'),
            tooltip: 'Asistente',
            icon: const Icon(Icons.auto_awesome_outlined),
            onPressed: () => context.push('/assistant'),
          ),
          IconButton(
            tooltip: unread > 0 ? '$unread notificaciones sin leer' : 'Notificaciones',
            icon: Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: const Icon(Icons.notifications_outlined)),
            onPressed: () => context.go('/notifications'),
          ),
        ],
      ),
      body: BlocBuilder<HomeExperienceCubit, Resource<SduiScreen>>(
        builder: (context, r) {
          final screen = r.data;
          return RefreshIndicator(
            onRefresh: () => _refresh(context),
            child: ListView(
              key: const Key('home_list'),
              padding: const EdgeInsets.fromLTRB(KSpace.md, KSpace.sm, KSpace.md, KSpace.xl),
              children: [
                if (screen?.isFallback ?? false) ...[
                  KCard(
                    child: Row(children: [
                      const Icon(Icons.info_outline),
                      const SizedBox(width: 12),
                      const Expanded(child: Text('Estamos mostrando una versión simplificada de tu inicio.')),
                      TextButton(onPressed: () => context.read<HomeExperienceCubit>().load(), child: const Text('Reintentar')),
                    ]),
                  ),
                  const SizedBox(height: KSpace.md),
                ] else if (r.isStale) ...[
                  StaleNotice(updatedAt: r.updatedAt, onRetry: () => _refresh(context)),
                  const SizedBox(height: KSpace.md),
                ],
                if (screen == null)
                  ..._skeleton()
                else
                  SduiRenderer(sections: screen.sections, registry: sl<SduiRegistry>(), telemetry: sl<Telemetry>()),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _skeleton() => const [
        Skeleton(height: 28, width: 220),
        SizedBox(height: KSpace.md),
        Skeleton(height: 140, radius: KRadius.hero),
        SizedBox(height: KSpace.md),
        Skeleton(height: 72, radius: KRadius.card),
        SizedBox(height: KSpace.md),
        Skeleton(height: 96, radius: KRadius.card),
      ];
}
