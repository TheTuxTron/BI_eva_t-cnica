import 'package:get_it/get_it.dart';

import '../../app/feature_module.dart';
import '../../core/cache/cache_store.dart';
import '../../core/network/api_client.dart';
import '../../sdui/sdui_registry.dart';
import 'data/fx_repository.dart';
import 'presentation/fx_cubit.dart';

class FxModule extends FeatureModule {
  @override
  String get name => 'fx';

  @override
  void registerDependencies(GetIt sl) => sl.registerLazySingleton(() => FxRepository(sl<ApiClient>(), sl<CacheStore>()));

  @override
  void registerComponents(SduiRegistry registry) => registry.register('fx_rates', (_, s) => FxRatesComponent(section: s));
}
