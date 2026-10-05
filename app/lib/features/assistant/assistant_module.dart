import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../app/feature_module.dart';
import '../../core/network/api_client.dart';
import 'data/assistant_repository.dart';
import 'presentation/assistant_page.dart';

class AssistantModule extends FeatureModule {
  @override
  String get name => 'assistant';

  @override
  void registerDependencies(GetIt sl) => sl.registerLazySingleton(() => AssistantRepository(sl<ApiClient>()));

  @override
  List<RouteBase> get routes => [GoRoute(path: '/assistant', builder: (_, __) => const AssistantPage())];
}
