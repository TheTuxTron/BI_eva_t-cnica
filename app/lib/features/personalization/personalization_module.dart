import 'package:get_it/get_it.dart';

import '../../app/feature_module.dart';
import '../../core/cache/cache_store.dart';
import '../../core/network/api_client.dart';
import '../../sdui/components/common_components.dart';
import '../../sdui/sdui_registry.dart';
import 'data/experience_repository.dart';

class PersonalizationModule extends FeatureModule {
  @override
  String get name => 'personalization';

  @override
  void registerDependencies(GetIt sl) => sl.registerLazySingleton(() => ExperienceRepository(sl<ApiClient>(), sl<CacheStore>()));

  @override
  void registerComponents(SduiRegistry registry) => registerCommonComponents(registry);
}
