import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../app/feature_module.dart';
import '../../core/cache/cache_store.dart';
import '../../core/network/api_client.dart';
import '../../sdui/sdui_registry.dart';
import 'data/accounts_repository.dart';
import 'presentation/account_detail_page.dart';
import 'presentation/account_widgets.dart';

class AccountsModule extends FeatureModule {
  @override
  String get name => 'accounts';

  @override
  void registerDependencies(GetIt sl) {
    sl.registerLazySingleton(() => AccountsRepository(sl<ApiClient>(), sl<CacheStore>()));
  }

  @override
  List<RouteBase> get routes => [
        GoRoute(
          path: '/accounts/:id',
          builder: (_, s) => AccountDetailPage(accountId: s.pathParameters['id']!, category: s.uri.queryParameters['category']),
        ),
      ];

  @override
  void registerComponents(SduiRegistry registry) {
    registry.register('account_summary', (_, s) => AccountSummaryComponent(section: s));
  }
}
