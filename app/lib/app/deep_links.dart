import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/observability/telemetry.dart';

/// Resolución centralizada de deeplinks provenientes de SDUI, push, asistente o micro-apps.
/// Lista blanca de destinos: el servidor no puede llevar al usuario a rutas arbitrarias.
class DeepLinks {
  DeepLinks(this.telemetry);
  final Telemetry telemetry;

  static const _tabRoots = {'/home', '/accounts', '/notifications', '/settings'};
  static const _allowedPrefixes = [
    '/home',
    '/accounts',
    '/notifications',
    '/settings',
    '/transfer',
    '/assistant',
    '/diagnostics',
  ];

  /// Convierte un deeplink en una ubicación del router, o null si no está permitido.
  static String? resolve(String link) {
    final uri = Uri.tryParse(link);
    if (uri == null) return null;
    if (uri.scheme == 'microapp') {
      final id = uri.host;
      if (!RegExp(r'^[a-z0-9-]{3,40}$').hasMatch(id)) return null;
      return Uri(
        path: '/microapp/$id',
        queryParameters: uri.queryParameters.isEmpty ? null : uri.queryParameters,
      ).toString();
    }
    if (uri.scheme.isEmpty && _allowedPrefixes.any((p) => uri.path == p || uri.path.startsWith('$p/'))) {
      return uri.toString();
    }
    return null;
  }

  void open(BuildContext context, String link, {String? source}) {
    final location = resolve(link);
    telemetry.event('deeplink_open', {'link': link, 'source': source, 'allowed': location != null});
    if (location == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Esta opción aún no está disponible.')));
      return;
    }
    final path = Uri.parse(location).path;
    if (_tabRoots.contains(path)) {
      context.go(location);
    } else {
      context.push(location);
    }
  }
}
