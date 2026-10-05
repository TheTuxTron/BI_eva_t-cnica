import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/cache/cache_store.dart';
import '../core/connectivity/connectivity_cubit.dart';
import '../core/network/api_client.dart';
import '../core/network/interceptors.dart';
import '../core/network/network_health.dart';
import '../core/observability/telemetry.dart';
import '../core/storage/token_store.dart';
import '../design_system/theme_cubit.dart';
import '../features/accounts/accounts_module.dart';
import '../features/assistant/assistant_module.dart';
import '../features/auth/auth_module.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/session_cubit.dart';
import '../features/diagnostics/diagnostics_page.dart';
import '../features/fx/fx_module.dart';
import '../features/microapps/microapps_module.dart';
import '../features/notifications/notifications_module.dart';
import '../features/personalization/data/experience_repository.dart';
import '../features/personalization/personalization_module.dart';
import '../features/transfers/transfers_module.dart';
import '../sdui/sdui_registry.dart';
import 'deep_links.dart';
import 'env.dart';
import 'feature_module.dart';

final GetIt sl = GetIt.instance;

const kAppVersion = '1.0.0';

/// Dominios funcionales registrados. Agregar un dominio = agregar su módulo aquí.
List<FeatureModule> buildModules({bool devTools = true}) => [
  AuthModule(),
  AccountsModule(),
  TransfersModule(),
  PersonalizationModule(),
  FxModule(),
  MicroappsModule(),
  NotificationsModule(),
  AssistantModule(),
  if (devTools) DiagnosticsModule(),
];

/// Composición de dependencias. [overrides] permite a los tests reemplazar piezas
/// (p. ej. PushService o TokenStore) antes de que se registren las reales.
Future<List<FeatureModule>> configureDependencies(
  AppEnv env, {
  SharedPreferences? prefs,
  TokenStore? tokenStore,
  void Function(GetIt sl)? overrides,
}) async {
  await sl.reset();
  sl.registerSingleton<AppEnv>(env);
  sl.registerSingleton<CacheStore>(CacheStore(prefs ?? await SharedPreferences.getInstance()));
  sl.registerSingleton<TokenStore>(tokenStore ?? TokenStore());
  sl.registerSingleton<NetworkHealth>(NetworkHealth());

  final behavior = BehaviorEventsTelemetry((events) => sl<ExperienceRepository>().sendEvents(events));
  sl.registerSingleton<BehaviorEventsTelemetry>(behavior);
  sl.registerSingleton<Telemetry>(CompositeTelemetry([ConsoleTelemetry(), behavior]));

  final base = BaseOptions(
    baseUrl: env.apiBaseUrl,
    connectTimeout: const Duration(seconds: 8),
    sendTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    contentType: 'application/json',
  );
  final platform = kIsWeb ? 'web' : defaultTargetPlatform.name;
  final dio = Dio(base);
  final refreshDio = Dio(base);
  dio.interceptors.addAll([
    RequestIdInterceptor(appVersion: kAppVersion, platform: platform),
    AuthInterceptor(
      tokens: sl<TokenStore>(),
      refreshDio: refreshDio,
      onSessionExpired: () => sl<SessionCubit>().expire(),
    ),
    RetryInterceptor(dio: dio, telemetry: sl<Telemetry>()),
    TelemetryInterceptor(sl<Telemetry>(), sl<NetworkHealth>()),
  ]);
  sl.registerSingleton<Dio>(dio);
  sl.registerSingleton<ApiClient>(ApiClient(dio));
  sl.registerSingleton<DeepLinks>(DeepLinks(sl<Telemetry>()));
  sl.registerSingleton<ThemeCubit>(ThemeCubit(sl<CacheStore>()));
  sl.registerLazySingleton<ConnectivityCubit>(() => ConnectivityCubit(health: sl<NetworkHealth>()));

  overrides?.call(sl);

  final modules = buildModules(devTools: env.enableDevTools);
  final registry = SduiRegistry();
  for (final m in modules) {
    m.registerDependencies(sl);
    m.registerComponents(registry);
  }
  sl.registerSingleton<SduiRegistry>(registry);
  sl.registerSingleton<SessionCubit>(SessionCubit(sl<AuthRepository>(), sl<Telemetry>()));
  return modules;
}
