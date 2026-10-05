import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../app/deep_links.dart';
import '../../app/di.dart';
import '../../core/network/api_client.dart';
import '../../core/observability/telemetry.dart';
import '../../app/feature_module.dart';
import '../../design_system/widgets.dart';
import '../../sdui/sdui_models.dart';
import '../../sdui/sdui_registry.dart';
import 'data/microapps_repository.dart';
import 'presentation/microapp_page.dart';

class MicroappsModule extends FeatureModule {
  @override
  String get name => 'microapps';

  @override
  void registerDependencies(GetIt sl) => sl.registerLazySingleton(() => MicroappsRepository(sl<ApiClient>()));

  @override
  List<RouteBase> get routes => [
        GoRoute(
          path: '/microapp/:id',
          builder: (_, s) => MicroappPage(appId: s.pathParameters['id']!, query: s.uri.queryParameters),
        ),
      ];

  @override
  void registerComponents(SduiRegistry registry) => registry.register('microapp_tile', (_, s) => MicroappTile(section: s));
}

class MicroappTile extends StatelessWidget {
  const MicroappTile({super.key, required this.section});
  final SduiSection section;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return KCard(
      onTap: () {
        sl<Telemetry>().event('action_simulator');
        sl<DeepLinks>().open(context, section.str('deeplink') ?? 'microapp://${section.str('appId')}', source: 'microapp_tile');
      },
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: scheme.tertiaryContainer, borderRadius: BorderRadius.circular(14)),
          child: Icon(Icons.calculate_rounded, color: scheme.onTertiaryContainer),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(section.str('title') ?? 'Simulador', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            Text(section.str('description') ?? '', style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
        const Icon(Icons.open_in_new_rounded, size: 20),
      ]),
    );
  }
}
