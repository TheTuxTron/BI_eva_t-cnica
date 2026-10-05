import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/failures.dart';
import '../../../core/observability/telemetry.dart';
import '../data/auth_repository.dart';
import 'session_cubit.dart';

class RegisterState extends Equatable {
  const RegisterState({this.step = 0, this.submitting = false, this.failure, this.ticket, this.fieldErrors = const {}});
  final int step;
  final bool submitting;
  final AppFailure? failure;
  final RegistrationTicket? ticket;
  final Map<String, String> fieldErrors;

  RegisterState copyWith({
    int? step,
    bool? submitting,
    AppFailure? failure,
    bool clearFailure = false,
    RegistrationTicket? ticket,
    Map<String, String>? fieldErrors,
  }) => RegisterState(
    step: step ?? this.step,
    submitting: submitting ?? this.submitting,
    failure: clearFailure ? null : (failure ?? this.failure),
    ticket: ticket ?? this.ticket,
    fieldErrors: fieldErrors ?? this.fieldErrors,
  );

  @override
  List<Object?> get props => [step, submitting, failure, ticket?.userId, fieldErrors];
}

/// Onboarding digital en pasos (identidad → contacto → seguridad) con métricas de embudo.
class RegisterCubit extends Cubit<RegisterState> {
  RegisterCubit(this._repo, this._telemetry) : super(const RegisterState()) {
    _telemetry.event('onboarding_started');
  }
  final AuthRepository _repo;
  final Telemetry _telemetry;

  static const _stepOfField = {
    'cedula': 0,
    'firstName': 0,
    'lastName': 0,
    'birthDate': 0,
    'email': 1,
    'phone': 1,
    'password': 2,
    'acceptTerms': 2,
  };

  void next() {
    _telemetry.event('onboarding_step_completed', {'step': state.step});
    emit(state.copyWith(step: state.step + 1, clearFailure: true));
  }

  void back() => emit(state.copyWith(step: state.step > 0 ? state.step - 1 : 0, clearFailure: true));

  Future<void> submit(RegistrationData data) async {
    emit(state.copyWith(submitting: true, clearFailure: true, fieldErrors: const {}));
    try {
      final ticket = await _repo.register(data);
      _telemetry.event('onboarding_registered');
      emit(state.copyWith(submitting: false, ticket: ticket));
    } on AppFailure catch (f) {
      final fields = f is BusinessFailure ? f.fieldErrors : const <String, String>{};
      // Vuelve al primer paso que contiene un campo con error del servidor.
      final firstStep = fields.keys
          .map((k) => _stepOfField[k] ?? state.step)
          .fold<int>(state.step, (a, b) => b < a ? b : a);
      _telemetry.event('onboarding_failed', {'code': f is BusinessFailure ? f.code : f.runtimeType.toString()});
      emit(state.copyWith(submitting: false, failure: f, fieldErrors: fields, step: firstStep));
    }
  }
}

class OtpState extends Equatable {
  const OtpState({this.submitting = false, this.failure, this.devOtp, this.resendIn = 30});
  final bool submitting;
  final AppFailure? failure;
  final String? devOtp;
  final int resendIn;
  @override
  List<Object?> get props => [submitting, failure, devOtp, resendIn];
}

class OtpCubit extends Cubit<OtpState> {
  OtpCubit(this._repo, this._session, this._telemetry, {required this.userId, String? devOtp})
    : super(OtpState(devOtp: devOtp));
  final AuthRepository _repo;
  final SessionCubit _session;
  final Telemetry _telemetry;
  final String userId;

  void tick() {
    if (state.resendIn > 0) emit(OtpState(devOtp: state.devOtp, resendIn: state.resendIn - 1, failure: state.failure));
  }

  Future<void> verify(String code) async {
    if (state.submitting || code.length != 6) return;
    emit(OtpState(submitting: true, devOtp: state.devOtp, resendIn: state.resendIn));
    try {
      final user = await _repo.verifyOtp(userId, code);
      _telemetry.event('onboarding_completed');
      _session.signedIn(user);
    } on AppFailure catch (f) {
      emit(OtpState(failure: f, devOtp: state.devOtp, resendIn: state.resendIn));
    }
  }

  Future<void> resend() async {
    try {
      final dev = await _repo.resendOtp(userId);
      emit(OtpState(devOtp: dev, resendIn: 30));
    } on AppFailure catch (f) {
      emit(OtpState(failure: f, devOtp: state.devOtp, resendIn: state.resendIn));
    }
  }
}
