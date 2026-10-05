import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/connectivity/connectivity_cubit.dart';
import '../core/observability/telemetry.dart';
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
import 'deep_links.dart';
import 'di.dart';

final GlobalKey<ScaffoldMessengerState> rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

class SessionScope extends StatefulWidget {
  const SessionScope({super.key, required this.router, required this.child});
  final GoRouter router;
  final Widget child;

  @override
  State<SessionScope> createState() => _SessionScopeState();
}

class _SessionScopeState extends State<SessionScope> {
  static const _releaseDelay = Duration(milliseconds: 800);
  String? _retainedUserId;
  Timer? _release;

  @override
  void dispose() {
    _release?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SessionCubit, SessionState>(
      listenWhen: (a, b) => a.status != b.status || a.user?.id != b.user?.id,
      listener: (context, session) {
        _release?.cancel();
        if (session.status != SessionStatus.authenticated && _retainedUserId != null) {
          _release = Timer(_releaseDelay, () {
            if (mounted) setState(() => _retainedUserId = null);
          });
        }
      },
      builder: (context, session) {
        final active = session.status == SessionStatus.authenticated;
        if (active) _retainedUserId = session.user!.id;
        final userId = _retainedUserId;
        if (userId == null) return widget.child;
        return MultiBlocProvider(
          key: ValueKey(userId),
          providers: [
            BlocProvider(create: (_) => AccountsCubit(sl<AccountsRepository>())..load()),
            BlocProvider(create: (_) => HomeExperienceCubit(sl<ExperienceRepository>(), sl<ThemeCubit>(), sl<Telemetry>())..load()),
            BlocProvider(create: (_) => FxCubit(sl<FxRepository>())..load()),
            BlocProvider(create: (_) => NotificationsCubit(sl<NotificationsRepository>())..refresh()),
          ],
          child: _SessionEffects(router: widget.router, active: active, child: widget.child),
        );
      },
    );
  }
}

class _SessionEffects extends StatefulWidget {
  const _SessionEffects({required this.router, required this.active, required this.child});
  final GoRouter router;
  final bool active;
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
      if (!mounted || !widget.active) return;
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
    _subs.add(_push.opened.listen((link) {
      if (widget.active) _go(link);
    }));
    if (widget.active) unawaited(_push.start());
  }

  @override
  void didUpdateWidget(covariant _SessionEffects old) {
    super.didUpdateWidget(old);
    // Al cerrar sesión, push y polling se detienen al instante (no esperan la liberación).
    if (old.active && !widget.active) unawaited(_push.stop());
  }

  void _go(String link) {
    final loc = DeepLinks.resolve(link);
    if (loc == null) return;
    widget.router.push(loc);
  }

  void _reloadAll() {
    if (!widget.active) return;
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