import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/observability/telemetry.dart';
import '../features/auth/presentation/session_cubit.dart';
import 'app.dart';
import 'di.dart';
import 'env.dart';

/// Arranque: dependencias → captura global de errores → restauración de sesión → UI.
Future<void> bootstrap({AppEnv? env}) async {
  WidgetsFlutterBinding.ensureInitialized();
  final e = env ?? AppEnv.fromDefines();
  final modules = await configureDependencies(e);
  final telemetry = sl<Telemetry>();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    telemetry.recordError(details.exception, details.stack, fatal: true, context: {'library': details.library});
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    telemetry.recordError(error, stack, fatal: true);
    return true;
  };

  final sw = Stopwatch()..start();
  await sl<SessionCubit>().restore();
  telemetry.metric('cold_start_restore_ms', sw.elapsedMilliseconds.toDouble());

  runApp(KintiApp(modules: modules));
}
