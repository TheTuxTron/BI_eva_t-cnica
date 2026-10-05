import 'package:get_it/get_it.dart';

import '../../app/env.dart';
import '../../app/feature_module.dart';
import '../../core/cache/cache_store.dart';
import '../../core/network/api_client.dart';
import '../../core/observability/telemetry.dart';
import 'data/notifications_repository.dart';
import 'data/push_service.dart';

class NotificationsModule extends FeatureModule {
  @override
  String get name => 'notifications';

  @override
  void registerDependencies(GetIt sl) {
    sl.registerLazySingleton(() => NotificationsRepository(sl<ApiClient>(), sl<CacheStore>()));
    if (!sl.isRegistered<PushService>()) {
      sl.registerLazySingleton<PushService>(
        () => HybridPushService(repo: sl<NotificationsRepository>(), telemetry: sl<Telemetry>(), pollEvery: sl<AppEnv>().pollingInterval),
      );
    }
  }
}
