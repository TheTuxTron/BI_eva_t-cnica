import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Fachada de observabilidad. Las features dependen de esta interfaz, no del proveedor
/// (Sentry, Crashlytics, Datadog…), así se puede cambiar de herramienta sin tocar features.
abstract class Telemetry {
  void event(String name, [Map<String, Object?> props = const {}]);
  void screen(String name);
  void metric(String name, double value, [Map<String, Object?> tags = const {}]);
  void breadcrumb(String message, {String category = 'app'});
  void recordError(Object error, StackTrace? stack, {bool fatal = false, Map<String, Object?> context = const {}});
  void setUser(String? userId);
}

class CompositeTelemetry implements Telemetry {
  CompositeTelemetry(this.sinks);
  final List<Telemetry> sinks;

  void _each(void Function(Telemetry t) f) {
    for (final s in sinks) {
      try {
        f(s);
      } catch (_) {/* la telemetría nunca debe romper la app */}
    }
  }

  @override
  void event(String name, [Map<String, Object?> props = const {}]) => _each((t) => t.event(name, props));
  @override
  void screen(String name) => _each((t) => t.screen(name));
  @override
  void metric(String name, double value, [Map<String, Object?> tags = const {}]) => _each((t) => t.metric(name, value, tags));
  @override
  void breadcrumb(String message, {String category = 'app'}) => _each((t) => t.breadcrumb(message, category: category));
  @override
  void recordError(Object error, StackTrace? stack, {bool fatal = false, Map<String, Object?> context = const {}}) =>
      _each((t) => t.recordError(error, stack, fatal: fatal, context: context));
  @override
  void setUser(String? userId) => _each((t) => t.setUser(userId));
}

/// Logs estructurados (JSON por línea) para desarrollo y para `adb logcat`.
class ConsoleTelemetry implements Telemetry {
  ConsoleTelemetry({this.verbose = kDebugMode});
  final bool verbose;
  final List<String> recent = [];

  void _log(Map<String, Object?> m) {
    final line = jsonEncode({'ts': DateTime.now().toIso8601String(), ...m});
    recent.add(line);
    if (recent.length > 200) recent.removeAt(0);
    if (verbose) debugPrint(line);
  }

  @override
  void event(String name, [Map<String, Object?> props = const {}]) => _log({'kind': 'event', 'name': name, ...props});
  @override
  void screen(String name) => _log({'kind': 'screen', 'name': name});
  @override
  void metric(String name, double value, [Map<String, Object?> tags = const {}]) =>
      _log({'kind': 'metric', 'name': name, 'value': value, ...tags});
  @override
  void breadcrumb(String message, {String category = 'app'}) => _log({'kind': 'breadcrumb', 'category': category, 'msg': message});
  @override
  void recordError(Object error, StackTrace? stack, {bool fatal = false, Map<String, Object?> context = const {}}) =>
      _log({'kind': 'error', 'fatal': fatal, 'error': error.toString(), ...context});
  @override
  void setUser(String? userId) => _log({'kind': 'user', 'id': userId});
}

/// Envía eventos de comportamiento en lotes al BFF: alimentan la personalización
/// (p. ej. reordenar acciones) y las métricas de UX del lado servidor.
class BehaviorEventsTelemetry implements Telemetry {
  BehaviorEventsTelemetry(this._send, {this.flushEvery = const Duration(seconds: 10)});
  final Future<void> Function(List<Map<String, Object?>> events) _send;
  final Duration flushEvery;
  final List<Map<String, Object?>> _buffer = [];
  Timer? _timer;
  bool enabled = false;

  static final _allowed = RegExp(r'^(action_|screen_|push_|microapp_)[a-z0-9_]+$');

  @override
  void event(String name, [Map<String, Object?> props = const {}]) {
    if (!enabled || !_allowed.hasMatch(name)) return;
    _buffer.add({'name': name, 'at': DateTime.now().toUtc().toIso8601String()});
    if (_buffer.length >= 20) {
      unawaited(flush());
    } else {
      _timer ??= Timer(flushEvery, () => unawaited(flush()));
    }
  }

  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    if (_buffer.isEmpty) return;
    final batch = List<Map<String, Object?>>.of(_buffer);
    _buffer.clear();
    try {
      await _send(batch);
    } catch (_) {
      // Mejor esfuerzo: si falla, se re-encolan (acotado) para el próximo flush.
      _buffer.insertAll(0, batch.take(50));
    }
  }

  @override
  void screen(String name) => event('screen_${name.replaceAll(RegExp('[^a-z0-9_]'), '_')}');
  @override
  void metric(String name, double value, [Map<String, Object?> tags = const {}]) {}
  @override
  void breadcrumb(String message, {String category = 'app'}) {}
  @override
  void recordError(Object error, StackTrace? stack, {bool fatal = false, Map<String, Object?> context = const {}}) {}
  @override
  void setUser(String? userId) => enabled = userId != null;
}
