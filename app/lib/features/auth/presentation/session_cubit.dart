import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/observability/telemetry.dart';
import '../data/auth_repository.dart';

enum SessionStatus { unknown, unauthenticated, authenticated }

class SessionState extends Equatable {
  const SessionState._(this.status, [this.user, this.expired = false]);
  const SessionState.unknown() : this._(SessionStatus.unknown);
  const SessionState.unauthenticated({bool expired = false}) : this._(SessionStatus.unauthenticated, null, expired);
  const SessionState.authenticated(UserProfile user) : this._(SessionStatus.authenticated, user);

  final SessionStatus status;
  final UserProfile? user;

  /// true si la sesión terminó por expiración/revocación (para avisar al usuario).
  final bool expired;

  @override
  List<Object?> get props => [status, user?.id, expired];
}

/// Fuente única de verdad de la sesión. El router redirige según este estado.
class SessionCubit extends Cubit<SessionState> {
  SessionCubit(this._repo, this._telemetry) : super(const SessionState.unknown());
  final AuthRepository _repo;
  final Telemetry _telemetry;

  Future<void> restore() async {
    final user = await _repo.restore();
    _set(user);
  }

  void signedIn(UserProfile user) => _set(user);

  Future<void> logout() async {
    await _repo.logout();
    _telemetry.event('logout');
    _set(null);
  }

  /// Llamado por el AuthInterceptor cuando el refresh token ya no es válido.
  Future<void> expire() async {
    if (state.status != SessionStatus.authenticated) return;
    await _repo.logout();
    _telemetry.event('session_expired');
    _telemetry.setUser(null);
    emit(const SessionState.unauthenticated(expired: true));
  }

  void _set(UserProfile? user) {
    _telemetry.setUser(user?.id);
    emit(user == null ? const SessionState.unauthenticated() : SessionState.authenticated(user));
  }
}
