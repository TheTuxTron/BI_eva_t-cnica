import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/failures.dart';
import '../../../core/observability/telemetry.dart';
import '../data/auth_repository.dart';
import 'session_cubit.dart';

class LoginState extends Equatable {
  const LoginState({this.submitting = false, this.failure});
  final bool submitting;
  final AppFailure? failure;
  @override
  List<Object?> get props => [submitting, failure];
}

class LoginCubit extends Cubit<LoginState> {
  LoginCubit(this._repo, this._session, this._telemetry) : super(const LoginState());
  final AuthRepository _repo;
  final SessionCubit _session;
  final Telemetry _telemetry;

  Future<void> submit(String username, String password) async {
    if (state.submitting) return;
    emit(const LoginState(submitting: true));
    final sw = Stopwatch()..start();
    try {
      final user = await _repo.login(username, password);
      _telemetry.event('login_success');
      _telemetry.metric('login_duration_ms', sw.elapsedMilliseconds.toDouble());
      _session.signedIn(user);
      emit(const LoginState());
    } on AppFailure catch (f) {
      _telemetry.event('login_failed', {'type': f.runtimeType.toString()});
      emit(LoginState(failure: f));
    }
  }
}
