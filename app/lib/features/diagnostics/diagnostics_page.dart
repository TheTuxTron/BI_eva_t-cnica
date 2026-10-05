import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../app/di.dart';
import '../../app/env.dart';
import '../../app/feature_module.dart';
import '../../core/cache/cache_store.dart';
import '../../core/connectivity/connectivity_cubit.dart';
import '../../core/network/network_health.dart';
import '../../core/observability/telemetry.dart';
import '../../design_system/tokens.dart';
import '../../design_system/widgets.dart';

/// Panel de QA/demo: controla la inyección de fallas del BFF para demostrar en vivo
/// estados de carga, reintentos, caché y recuperación. Solo existe con DEV_TOOLS=true.
class DiagnosticsPage extends StatefulWidget {
  const DiagnosticsPage({super.key});
  @override
  State<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends State<DiagnosticsPage> {
  late final Dio _admin = Dio(
    BaseOptions(
      baseUrl: sl<AppEnv>().apiBaseUrl,
      connectTimeout: const Duration(seconds: 5),
      headers: {'X-Admin-Key': sl<AppEnv>().adminKey},
    ),
  );
  Map<String, dynamic>? _chaos;
  String? _error;
  bool _busy = false;

  static const _presets = <(String, String, Map<String, Object>)>[
    (
      'Normal',
      'Sin fallas',
      {'enabled': false, 'latencyMs': 0, 'jitterMs': 0, 'errorRate': 0, 'groups': <String>[], 'outages': <String>[]},
    ),
    (
      'Latencia alta',
      '3 s ± 1 s en todos los dominios',
      {
        'enabled': true,
        'latencyMs': 3000,
        'jitterMs': 1000,
        'errorRate': 0,
        'groups': <String>[],
        'outages': <String>[],
      },
    ),
    (
      'Errores intermitentes',
      '40% de 503 en cuentas y transferencias',
      {
        'enabled': true,
        'latencyMs': 0,
        'jitterMs': 0,
        'errorRate': 0.4,
        'groups': ['accounts', 'transfers'],
        'outages': <String>[],
      },
    ),
    (
      'Cae personalización',
      'El inicio usa caché o experiencia embebida',
      {
        'enabled': true,
        'latencyMs': 0,
        'jitterMs': 0,
        'errorRate': 0,
        'groups': <String>[],
        'outages': ['experience'],
      },
    ),
    (
      'Cae tipo de cambio',
      'Solo el módulo FX se degrada',
      {
        'enabled': true,
        'latencyMs': 0,
        'jitterMs': 0,
        'errorRate': 0,
        'groups': <String>[],
        'outages': ['fx'],
      },
    ),
    (
      'Caen cuentas',
      'Saldos desde caché; transferir no disponible',
      {
        'enabled': true,
        'latencyMs': 0,
        'jitterMs': 0,
        'errorRate': 0,
        'groups': <String>[],
        'outages': ['accounts', 'transfers'],
      },
    ),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await _admin.get<Map<String, dynamic>>('/v1/admin/chaos');
      setState(() {
        _chaos = r.data;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'No se pudo leer el estado del BFF: $e');
    }
  }

  Future<void> _apply(Map<String, Object> body) async {
    setState(() => _busy = true);
    try {
      final r = await _admin.put<Map<String, dynamic>>('/v1/admin/chaos', data: body);
      sl<Telemetry>().event('chaos_applied', {'config': body.toString()});
      setState(() {
        _chaos = r.data;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final env = sl<AppEnv>();
    final conn = context.watch<ConnectivityCubit>().state;
    final ids = sl<NetworkHealth>().recentRequestIds;
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnóstico y resiliencia')),
      body: ListView(
        padding: const EdgeInsets.all(KSpace.md),
        children: [
          KCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Entorno: ${env.flavor}', style: Theme.of(context).textTheme.titleSmall),
                Text('API: ${env.apiBaseUrl}'),
                Text(
                  'Enlace: ${conn.isOffline ? 'sin conexión' : 'en línea'} · Calidad: ${conn.isDegraded ? 'degradada' : 'normal'}',
                ),
              ],
            ),
          ),
          const SizedBox(height: KSpace.md),
          const SectionTitle('Escenarios de falla (BFF)'),
          if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          if (_chaos != null)
            Text(
              'Activo: ${_chaos!['enabled'] == true ? _chaos.toString() : 'ninguno'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: KSpace.sm),
          for (final (title, desc, body) in _presets)
            Padding(
              padding: const EdgeInsets.only(bottom: KSpace.sm),
              child: KCard(
                onTap: _busy ? null : () => _apply(body),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: Theme.of(context).textTheme.titleSmall),
                          Text(desc, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    const Icon(Icons.play_arrow_rounded),
                  ],
                ),
              ),
            ),
          const SizedBox(height: KSpace.md),
          const SectionTitle('Datos locales'),
          OutlinedButton.icon(
            onPressed: () async {
              await sl<CacheStore>().clearAll();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Caché local eliminada')));
              }
            },
            icon: const Icon(Icons.delete_outline),
            label: const Text('Borrar caché (simular primer arranque)'),
          ),
          const SizedBox(height: KSpace.md),
          const SectionTitle('Últimos X-Request-Id'),
          for (final id in ids.take(8))
            ListTile(
              dense: true,
              title: Text(id, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
              trailing: IconButton(
                tooltip: 'Copiar',
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () => Clipboard.setData(ClipboardData(text: id)),
              ),
            ),
        ],
      ),
    );
  }
}

class DiagnosticsModule extends FeatureModule {
  @override
  String get name => 'diagnostics';

  @override
  List<RouteBase> get routes => [GoRoute(path: '/diagnostics', builder: (_, __) => const DiagnosticsPage())];
}
