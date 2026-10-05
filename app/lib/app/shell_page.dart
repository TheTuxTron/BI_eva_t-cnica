import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/connectivity/connectivity_cubit.dart';
import '../design_system/tokens.dart';
import '../features/notifications/presentation/notifications_cubit.dart';

class ShellPage extends StatelessWidget {
  const ShellPage({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final unread = context.select((NotificationsCubit c) => c.state.unread);
    return Scaffold(
      body: shell,
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        const ConnectivityBanner(),
        NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
          destinations: [
            const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Inicio'),
            const NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet_rounded), label: 'Cuentas'),
            NavigationDestination(
              icon: Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: const Icon(Icons.notifications_outlined)),
              selectedIcon: const Icon(Icons.notifications_rounded),
              label: 'Avisos',
            ),
            const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person_rounded), label: 'Perfil'),
          ],
        ),
      ]),
    );
  }
}

/// Banner persistente de estado de red: sin conexión, inestable o recuperada.
class ConnectivityBanner extends StatefulWidget {
  const ConnectivityBanner({super.key});
  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  bool _showRecovered = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ConnectivityCubit, ConnectivityState>(
      listenWhen: (a, b) => b.justRecovered && !a.justRecovered,
      listener: (_, __) {
        setState(() => _showRecovered = true);
        _timer?.cancel();
        _timer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _showRecovered = false);
        });
      },
      builder: (context, s) {
        final (Color? bg, IconData? icon, String? text) = s.isOffline
            ? (KColors.ink, Icons.wifi_off_rounded, 'Sin conexión · mostrando datos guardados')
            : s.isDegraded
                ? (KColors.warning, Icons.network_check_rounded, 'Conexión inestable · reintentando')
                : _showRecovered
                    ? (KColors.positive, Icons.check_rounded, 'Conexión restablecida')
                    : (null, null, null);
        return AnimatedSize(
          duration: KMotion.medium,
          child: text == null
              ? const SizedBox(width: double.infinity)
              : Semantics(
                  liveRegion: true,
                  child: Container(
                    key: const Key('connectivity_banner'),
                    width: double.infinity,
                    color: bg,
                    padding: const EdgeInsets.symmetric(horizontal: KSpace.md, vertical: 8),
                    child: Row(children: [
                      Icon(icon, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                    ]),
                  ),
                ),
        );
      },
    );
  }
}

