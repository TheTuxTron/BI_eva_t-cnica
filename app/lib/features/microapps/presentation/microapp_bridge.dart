import 'dart:convert';

/// Contrato v1 del bridge host ↔ micro-app (docs/microapps-contract.md).
/// Se mantiene puro (sin WebView) para poder probarlo con tests unitarios.
sealed class BridgeCommand {
  const BridgeCommand();
}

class BridgeReady extends BridgeCommand {
  const BridgeReady();
}

class BridgeNavigate extends BridgeCommand {
  const BridgeNavigate(this.route);
  final String route;
}

class BridgeTrack extends BridgeCommand {
  const BridgeTrack(this.event);
  final String event;
}

class BridgeClose extends BridgeCommand {
  const BridgeClose();
}

class BridgeSessionExpired extends BridgeCommand {
  const BridgeSessionExpired();
}

class BridgeRejected extends BridgeCommand {
  const BridgeRejected(this.reason);
  final String reason;
}

class MicroappBridge {
  MicroappBridge({required this.allowedNavigation});
  final List<String> allowedNavigation;
  static const version = 1;

  BridgeCommand parse(String raw) {
    if (raw.length > 4096) return const BridgeRejected('mensaje demasiado grande');
    Object? msg;
    try {
      msg = jsonDecode(raw);
    } catch (_) {
      return const BridgeRejected('JSON inválido');
    }
    if (msg is! Map || msg['v'] != version) return const BridgeRejected('versión de contrato no soportada');
    switch (msg['type']) {
      case 'ready':
        return const BridgeReady();
      case 'close':
        return const BridgeClose();
      case 'session_expired':
        return const BridgeSessionExpired();
      case 'track':
        final e = msg['event'];
        return e is String && RegExp(r'^microapp_[a-z0-9_]{2,40}$').hasMatch(e)
            ? BridgeTrack(e)
            : const BridgeRejected('evento inválido');
      case 'navigate':
        final r = msg['route'];
        // La micro-app solo puede navegar a rutas que el host le autorizó.
        return r is String && allowedNavigation.contains(r)
            ? BridgeNavigate(r)
            : BridgeRejected('ruta no autorizada: $r');
      default:
        return BridgeRejected('tipo desconocido: ${msg['type']}');
    }
  }

  static String sessionMessage({
    required String token,
    required String apiBase,
    required Map<String, dynamic> context,
  }) => jsonEncode({'v': version, 'type': 'session', 'token': token, 'apiBase': apiBase, 'context': context});
}
