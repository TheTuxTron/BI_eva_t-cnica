import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import '../core/connectivity/connectivity_cubit.dart';
import '../core/observability/telemetry.dart';
import '../design_system/theme.dart';
import '../design_system/theme_cubit.dart';
import '../features/auth/presentation/session_cubit.dart';
import 'di.dart';
import 'feature_module.dart';
import 'router.dart';
import 'session_scope.dart';

class KintiApp extends StatefulWidget {
  const KintiApp({super.key, required this.modules});
  final List<FeatureModule> modules;
  @override
  State<KintiApp> createState() => _KintiAppState();
}

class _KintiAppState extends State<KintiApp> {
  late final GoRouter _router = buildRouter(sl<SessionCubit>(), widget.modules);
  String? _lastPath;

  @override
  void initState() {
    super.initState();
    // Telemetría de pantallas (incluye pestañas del shell, que un NavigatorObserver no ve).
    _router.routerDelegate.addListener(() {
      final path = _router.routerDelegate.currentConfiguration.uri.path;
      if (path != _lastPath) {
        _lastPath = path;
        sl<Telemetry>().screen(path.replaceAll(RegExp(r'/[a-z]+_[A-Za-z0-9]+'), '/:id'));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: sl<SessionCubit>()),
        BlocProvider.value(value: sl<ThemeCubit>()),
        BlocProvider.value(value: sl<ConnectivityCubit>()),
      ],
      child: BlocListener<SessionCubit, SessionState>(
        // Al salir, se vuelve al tema neutro para no mostrar la marca del segmento anterior.
        listenWhen: (a, b) => b.status == SessionStatus.unauthenticated && a.status != b.status,
        listener: (_, __) => sl<ThemeCubit>().reset(),
        child: BlocBuilder<ThemeCubit, ThemeState>(
        builder: (context, theme) => MaterialApp.router(
          title: 'Kinti',
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: rootMessengerKey,
          theme: KTheme.build(seed: theme.seed, brightness: Brightness.light, segment: theme.segment),
          darkTheme: KTheme.build(seed: theme.seed, brightness: Brightness.dark, segment: theme.segment),
          themeMode: theme.mode,
          locale: const Locale('es'),
          supportedLocales: const [Locale('es'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          routerConfig: _router,
          builder: (context, child) => SessionScope(router: _router, child: child ?? const SizedBox.shrink()),
        ),
      ),
      ),
    );
  }
}
