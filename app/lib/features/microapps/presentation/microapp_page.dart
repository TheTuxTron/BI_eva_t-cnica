import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../app/deep_links.dart';
import '../../../app/di.dart';
import '../../../app/env.dart';
import '../../../core/network/failures.dart';
import '../../../core/observability/telemetry.dart';
import '../../../design_system/widgets.dart';
import '../data/microapps_repository.dart';
import 'microapp_bridge.dart';

/// Contenedor de micro-apps externas (otro equipo / tercero). Aislamiento:
/// - token propio de alcance limitado, entregado por el bridge (no por URL)
/// - navegación restringida al origen de la micro-app
/// - mensajes validados contra el contrato y lista blanca de rutas
class MicroappPage extends StatefulWidget {
  const MicroappPage({super.key, required this.appId, this.query = const {}});
  final String appId;
  final Map<String, String> query;
  @override
  State<MicroappPage> createState() => _MicroappPageState();
}

class _MicroappPageState extends State<MicroappPage> {
  final _telemetry = sl<Telemetry>();
  WebViewController? _controller;
  MicroappSession? _session;
  MicroappBridge? _bridge;
  AppFailure? _failure;
  bool _ready = false;
  Timer? _readyTimeout;
  final _sw = Stopwatch();

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _readyTimeout?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _failure = null;
      _ready = false;
    });
    _sw
      ..reset()
      ..start();
    try {
      final session = await sl<MicroappsRepository>().createSession(widget.appId);
      final url = reachableUrl(
        Uri.parse(session.url),
        Uri.parse(sl<AppEnv>().apiBaseUrl),
      ).replace(queryParameters: widget.query.isEmpty ? null : widget.query);
      final origin = url.origin;
      final controller = WebViewController();
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.addJavaScriptChannel('KintiHost', onMessageReceived: (m) => _onMessage(m.message));
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (req) {
            final allowed = Uri.parse(req.url).origin == origin;
            if (!allowed) _telemetry.event('microapp_navigation_blocked', {'url': req.url});
            return allowed ? NavigationDecision.navigate : NavigationDecision.prevent;
          },
          onWebResourceError: (e) {
            if (e.isForMainFrame ?? true) {
              _fail(NetworkFailure(detail: 'WebView ${e.errorCode}: ${e.description}'));
            }
          },
        ),
      );
      _readyTimeout = Timer(const Duration(seconds: 12), () {
        if (!_ready) _fail(const TimeoutFailure());
      });
      // Se asignan antes de cargar: el mensaje 'ready' puede llegar en cuanto la página carga.
      _session = session;
      _bridge = MicroappBridge(allowedNavigation: session.allowedNavigation);
      _controller = controller;
      await controller.loadRequest(url);
      if (mounted) setState(() {});
    } catch (e) {
      _fail(AppFailure.from(e));
    }
  }

  void _fail(AppFailure f) {
    if (!mounted) return;
    _telemetry.event('microapp_load_failed', {'app': widget.appId, 'type': f.runtimeType.toString()});
    setState(() => _failure = f);
  }

  Future<void> _onMessage(String raw) async {
    final bridge = _bridge ?? MicroappBridge(allowedNavigation: const []);
    final cmd = bridge.parse(raw);
    switch (cmd) {
      case BridgeReady():
        _ready = true;
        _readyTimeout?.cancel();
        _telemetry.metric('microapp_ready_ms', _sw.elapsedMilliseconds.toDouble(), {'app': widget.appId});
        await _sendSession();
        if (mounted) setState(() {});
      case BridgeNavigate(:final route):
        if (mounted) sl<DeepLinks>().open(context, route, source: 'microapp:${widget.appId}');
      case BridgeTrack(:final event):
        _telemetry.event(event, {'app': widget.appId});
      case BridgeClose():
        if (mounted) context.pop();
      case BridgeSessionExpired():
        try {
          _session = await sl<MicroappsRepository>().createSession(widget.appId);
          await _sendSession();
        } catch (e) {
          _fail(AppFailure.from(e));
        }
      case BridgeRejected(:final reason):
        _telemetry.event('microapp_message_rejected', {'app': widget.appId, 'reason': reason});
    }
  }

  Future<void> _sendSession() async {
    final s = _session;
    final c = _controller;
    if (s == null || c == null) return;
    final msg = MicroappBridge.sessionMessage(token: s.token, apiBase: sl<AppEnv>().apiBaseUrl, context: s.context);
    await c.runJavaScript('window.kintiReceive && window.kintiReceive($msg);');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simulador financiero'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: (_ready || _failure != null) ? const SizedBox(height: 2) : const LinearProgressIndicator(minHeight: 2),
        ),
      ),
      body:
          _failure != null
              ? Center(child: ErrorView(failure: _failure!, onRetry: _start))
              : _controller == null
              ? const Center(child: CircularProgressIndicator())
              : WebViewWidget(controller: _controller!),
    );
  }
}

/// Dentro de un emulador/celular, "localhost" apunta al propio dispositivo. Si el backend
/// devolvió una URL local, se reescribe al host por el que la app sí llega al BFF.
Uri reachableUrl(Uri microappUrl, Uri apiBase) {
  const local = {'localhost', '127.0.0.1', '0.0.0.0'};
  if (local.contains(microappUrl.host) && !local.contains(apiBase.host)) {
    return microappUrl.replace(scheme: apiBase.scheme, host: apiBase.host, port: apiBase.port);
  }
  return microappUrl;
}
