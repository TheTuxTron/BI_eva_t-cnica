import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../network/network_health.dart';

enum LinkStatus { online, offline }

class ConnectivityState extends Equatable {
  const ConnectivityState({
    this.link = LinkStatus.online,
    this.quality = NetworkQuality.healthy,
    this.justRecovered = false,
  });
  final LinkStatus link;
  final NetworkQuality quality;
  final bool justRecovered;

  bool get isOffline => link == LinkStatus.offline;
  bool get isDegraded => !isOffline && quality == NetworkQuality.degraded;

  @override
  List<Object?> get props => [link, quality, justRecovered];
}

/// Combina el estado del enlace (connectivity_plus) con la salud real del tráfico.
/// Al recuperarse la conexión emite justRecovered para que las pantallas refresquen.
class ConnectivityCubit extends Cubit<ConnectivityState> {
  ConnectivityCubit({required NetworkHealth health, Stream<List<ConnectivityResult>>? changes})
    : _health = health,
      super(const ConnectivityState()) {
    _health.addListener(_onHealth);
    _sub = (changes ?? Connectivity().onConnectivityChanged).listen(_onLink);
  }

  final NetworkHealth _health;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  void _onLink(List<ConnectivityResult> results) {
    final offline = results.isEmpty || results.every((r) => r == ConnectivityResult.none);
    final wasOffline = state.isOffline;
    emit(
      ConnectivityState(
        link: offline ? LinkStatus.offline : LinkStatus.online,
        quality: _health.value,
        justRecovered: wasOffline && !offline,
      ),
    );
  }

  void _onHealth() {
    final recovered = state.quality == NetworkQuality.degraded && _health.value == NetworkQuality.healthy;
    emit(ConnectivityState(link: state.link, quality: _health.value, justRecovered: recovered));
  }

  @override
  Future<void> close() {
    _health.removeListener(_onHealth);
    _sub?.cancel();
    return super.close();
  }
}
