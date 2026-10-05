import 'package:get_it/get_it.dart';

import '../../app/feature_module.dart';
import '../../core/cache/cache_store.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/token_store.dart';
import 'data/auth_repository.dart';

class AuthModule extends FeatureModule {
  @override
  String get name => 'auth';

  @override
  void registerDependencies(GetIt sl) {
    sl.registerLazySingleton(
      () => AuthRepository(api: sl<ApiClient>(), tokens: sl<TokenStore>(), cache: sl<CacheStore>()),
    );
  }
}
