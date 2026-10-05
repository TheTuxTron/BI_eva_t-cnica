import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../core/observability/telemetry.dart';
import 'notifications_repository.dart';

/// Abstracción de push: las features consumen estos streams sin saber el canal real.
abstract class PushService {
  /// Notificaciones nuevas mientras la app está en primer plano (se muestran in-app).
  Stream<AppNotification> get foreground;

  /// Deeplinks de notificaciones del sistema que el usuario tocó.
  Stream<String> get opened;

  Future<void> start();
  Future<void> stop();
  String get channelDescription;
}

@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // El SO muestra la notificación; la bandeja del BFF es la fuente de verdad al reabrir la app.
}

/// FCM cuando hay configuración de Firebase; si no, polling de la bandeja en primer plano.
/// En ambos casos la bandeja persistida en el BFF garantiza que nada se pierde.
class HybridPushService with WidgetsBindingObserver implements PushService {
  HybridPushService({required this.repo, required this.telemetry, required this.pollEvery});
  final NotificationsRepository repo;
  final Telemetry telemetry;
  final Duration pollEvery;

  final _foreground = StreamController<AppNotification>.broadcast();
  final _opened = StreamController<String>.broadcast();
  final List<StreamSubscription<Object?>> _subs = [];
  Timer? _timer;
  DateTime _lastSeen = DateTime.now().toUtc();
  bool _fcm = false;
  bool _running = false;
  bool _polling = false;

  @override
  Stream<AppNotification> get foreground => _foreground.stream;
  @override
  Stream<String> get opened => _opened.stream;

  @override
  String get channelDescription => _fcm ? 'Push activas (Firebase Cloud Messaging)' : 'Avisos dentro de la app (push no configurado en este entorno)';

  @override
  Future<void> start() async {
    if (_running) return;
    _running = true;
    _lastSeen = DateTime.now().toUtc();
    WidgetsBinding.instance.addObserver(this);
    _fcm = await _initFcm();
    telemetry.event(_fcm ? 'push_enabled' : 'push_fallback_polling');
    _startPolling();
  }

  @override
  Future<void> stop() async {
    _running = false;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_running) return;
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      unawaited(_poll());
    } else if (state == AppLifecycleState.paused) {
      _timer?.cancel();
    }
  }

  void _startPolling() {
    _timer?.cancel();
    // Con FCM el polling es solo una red de seguridad (cada 4x el intervalo).
    _timer = Timer.periodic(_fcm ? pollEvery * 4 : pollEvery, (_) => _poll());
  }

  Future<void> _poll() async {
    if (_polling) return;
    _polling = true;
    try {
      final inbox = await repo.since(_lastSeen);
      for (final n in inbox.items.reversed) {
        if (n.createdAt.isAfter(_lastSeen)) _lastSeen = n.createdAt.toUtc();
        if (!n.read) _foreground.add(n);
      }
    } catch (_) {
      // Silencioso: el banner de conectividad ya informa al usuario.
    } finally {
      _polling = false;
    }
  }

  Future<bool> _initFcm() async {
    if (kIsWeb) return false;
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
      final m = FirebaseMessaging.instance;
      final settings = await m.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        telemetry.event('push_permission_denied');
        return false;
      }
      final token = await m.getToken();
      if (token == null) return false;
      final platform = defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
      final serverFcm = await repo.registerDevice(token, platform);
      _subs.add(m.onTokenRefresh.listen((t) => repo.registerDevice(t, platform)));
      _subs.add(FirebaseMessaging.onMessage.listen((msg) {
        final n = msg.notification;
        _foreground.add(AppNotification(
          id: msg.data['notificationId']?.toString() ?? msg.messageId ?? '${DateTime.now().millisecondsSinceEpoch}',
          title: n?.title ?? 'Kinti',
          body: n?.body ?? '',
          deeplink: (msg.data['deeplink'] as String?)?.isEmpty ?? true ? null : msg.data['deeplink'] as String,
          createdAt: DateTime.now(),
        ));
        _lastSeen = DateTime.now().toUtc();
      }));
      _subs.add(FirebaseMessaging.onMessageOpenedApp.listen(_handleOpened));
      final initial = await m.getInitialMessage();
      if (initial != null) _handleOpened(initial);
      return serverFcm;
    } catch (e) {
      telemetry.event('push_fcm_unavailable', {'reason': e.runtimeType.toString()});
      return false;
    }
  }

  void _handleOpened(RemoteMessage msg) {
    telemetry.event('push_opened');
    final link = msg.data['deeplink'];
    if (link is String && link.isNotEmpty) _opened.add(link);
  }
}
