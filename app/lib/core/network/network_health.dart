import 'package:flutter/foundation.dart';

enum NetworkQuality { healthy, degraded }

/// Señal de salud derivada del tráfico real (no solo del estado del Wi-Fi/datos):
/// varias fallas transitorias seguidas → degradado; una respuesta OK → sano.
class NetworkHealth extends ValueNotifier<NetworkQuality> {
  NetworkHealth() : super(NetworkQuality.healthy);
  int _consecutiveFailures = 0;
  final List<String> recentRequestIds = [];

  void onSuccess(String? requestId) {
    _consecutiveFailures = 0;
    _remember(requestId);
    if (value != NetworkQuality.healthy) value = NetworkQuality.healthy;
  }

  void onTransientFailure(String? requestId) {
    _consecutiveFailures++;
    _remember(requestId);
    if (_consecutiveFailures >= 2 && value != NetworkQuality.degraded) value = NetworkQuality.degraded;
  }

  void _remember(String? id) {
    if (id == null) return;
    recentRequestIds.insert(0, id);
    if (recentRequestIds.length > 20) recentRequestIds.removeLast();
  }
}
