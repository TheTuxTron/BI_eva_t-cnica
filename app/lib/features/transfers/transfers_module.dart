import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../app/feature_module.dart';
import '../../core/network/api_client.dart';
import 'data/transfers_repository.dart';
import 'presentation/transfer_page.dart';

class TransfersModule extends FeatureModule {
  @override
  String get name => 'transfers';

  @override
  void registerDependencies(GetIt sl) => sl.registerLazySingleton(() => TransfersRepository(sl<ApiClient>()));

  @override
  List<RouteBase> get routes => [
        GoRoute(path: '/transfer', builder: (_, s) => TransferPage(fromAccountId: s.uri.queryParameters['from'])),
      ];
}
