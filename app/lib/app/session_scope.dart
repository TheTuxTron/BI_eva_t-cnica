import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/connectivity/connectivity_cubit.dart';
import '../design_system/theme_cubit.dart';
import '../features/accounts/data/accounts_repository.dart';
import '../features/accounts/presentation/accounts_cubit.dart';
import '../features/auth/presentation/session_cubit.dart';
import '../features/fx/data/fx_repository.dart';
import '../features/fx/presentation/fx_cubit.dart';
import '../features/notifications/data/notifications_repository.dart';
import '../features/notifications/data/push_service.dart';
import '../features/notifications/presentation/notifications_cubit.dart';
import '../features/personalization/data/experience_repository.dart';
import '../features/personalization/presentation/home_experience_cubit.dart';
import '../core/observability/telemetry.dart';
import 'deep_links.dart';
import 'di.dart';

final GlobalKey<ScaffoldMessengerState> rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Estado que vive mientras dura la sesión de UN usuario. Se crea al autenticarse y se
/// destruye al cerrar sesión (key = userId), así nunca se filtran datos entre usuarios.
/// Está por encima del Navigator: lo comparten pestañas y pantallas completas.
class SessionScope extends StatelessWidget {
  const SessionScope({super.key, required this.router, required this.child});
  final GoRouter router;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionCubit, SessionState>(
      buildWhen: (a, b) => a.user?.id != b.user?.id || a.status != b.status,
      builder: (context, session) {
        if (session.status != SessionStatus.authenticated) return child;
        return MultiBlocProvider(
          key: ValueKey(session.user!.id),
          providers: [
            BlocProvider(create: (_) => AccountsCubit(sl<AccountsRepository>())..load()),
            BlocProvider(create: (_) => HomeExperienceCubit(sl<ExperienceRepository>(), sl<ThemeCubit>(), sl<Telemetry>())..load()),
            BlocProvider(create: (_) => FxCubit(sl<FxRepository>())..load()),
            BlocProvider(create: (_) => NotificationsCubit(sl<NotificationsRepository>())..refresh()),
          ],
          child: _SessionEffects(router: router, child: child),
        );
      },
    );
  }
}

class _SessionEffects extends StatefulWidget {
  const _SessionEffects({required this.router, required this.child});
  final GoRouter router;
  final Widget child;
  @override
  State<_SessionEffects> createState() => _SessionEffectsState();
}

class _SessionEffectsState extends State<_SessionEffects> {
  final _subs = <StreamSubscription<Object?>>[];
  late final PushService _push = sl<PushService>();

  @override
  void initState() {
    super.initState();
    _subs.add(_push.foreground.listen((n) {
      if (!mounted) return;
      final notifications = context.read<NotificationsCubit>();
      final accounts = context.read<AccountsCubit>();
      notifications.received(n);
      // Un aviso de dinero recibido cambia saldos: se refrescan en segundo plano.
      unawaited(accounts.load());
      rootMessengerKey.currentState?.showSnackBar(SnackBar(
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(n.title, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(n.body),
        ]),
        action: n.deeplink == null ? null : SnackBarAction(label: 'Ver', onPressed: () => _go(n.deeplink!)),
        duration: const Duration(seconds: 5),
      ));
    }));
    _subs.add(_push.opened.listen(_go));
    unawaited(_push.start());
  }

  void _go(String link) {
    final loc = DeepLinks.resolve(link);
    if (loc == null) return;
    widget.router.push(loc);
  }

  void _reloadAll() {
    unawaited(context.read<AccountsCubit>().load());
    unawaited(context.read<HomeExperienceCubit>().load());
    unawaited(context.read<FxCubit>().load());
    unawaited(context.read<NotificationsCubit>().refresh());
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    unawaited(_push.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Al recuperar la conexión, se revalida todo automáticamente (recuperación sin acción del usuario).
    return BlocListener<ConnectivityCubit, ConnectivityState>(
      listenWhen: (a, b) => b.justRecovered && !a.justRecovered,
      listener: (_, __) => _reloadAll(),
      child: widget.child,
    );
  }
}
