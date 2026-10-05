import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/accounts/presentation/accounts_page.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/otp_page.dart';
import '../features/auth/presentation/register_page.dart';
import '../features/auth/presentation/session_cubit.dart';
import '../features/auth/presentation/welcome_page.dart';
import '../features/notifications/presentation/notifications_page.dart';
import '../features/personalization/presentation/home_page.dart';
import '../features/personalization/presentation/settings_page.dart';
import 'feature_module.dart';
import 'shell_page.dart';

const _publicPaths = {'/welcome', '/login', '/register', '/register/otp'};

/// Notifica a GoRouter cuando cambia la sesión para re-evaluar el redirect.
class _SessionListenable extends ChangeNotifier {
  _SessionListenable(Stream<SessionState> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }
  late final StreamSubscription<SessionState> _sub;
  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

GoRouter buildRouter(SessionCubit session, List<FeatureModule> modules) {
  return GoRouter(
    initialLocation: '/home',
    refreshListenable: _SessionListenable(session.stream),
    redirect: (context, state) {
      final status = session.state.status;
      final path = state.uri.path;
      if (status == SessionStatus.unknown) return path == '/splash' ? null : '/splash';
      final isPublic = _publicPaths.contains(path);
      if (status == SessionStatus.unauthenticated) {
        if (session.state.expired && path != '/login') return '/login';
        return isPublic ? null : '/welcome';
      }
      if (isPublic || path == '/splash') return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const Scaffold(body: Center(child: CircularProgressIndicator()))),
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomePage()),
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),
      GoRoute(
        path: '/register/otp',
        redirect: (_, s) => s.extra is RegistrationTicket ? null : '/register',
        builder: (_, s) => OtpPage(ticket: s.extra! as RegistrationTicket),
      ),
      for (final m in modules) ...m.routes,
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => ShellPage(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, __) => const HomePage())]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/accounts', builder: (_, s) => AccountsPage(category: s.uri.queryParameters['category'])),
          ]),
          StatefulShellBranch(routes: [GoRoute(path: '/notifications', builder: (_, __) => const NotificationsPage())]),
          StatefulShellBranch(routes: [GoRoute(path: '/settings', builder: (_, __) => const SettingsPage())]),
        ],
      ),
    ],
  );
}
