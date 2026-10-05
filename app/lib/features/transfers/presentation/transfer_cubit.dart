import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/failures.dart';
import '../../../core/observability/telemetry.dart';
import '../../accounts/data/accounts_repository.dart';
import '../data/transfers_repository.dart';

enum TransferStep { form, confirm, processing, success, uncertain, rejected }

class TransferState extends Equatable {
  const TransferState({
    this.step = TransferStep.form,
    this.fromAccountId,
    this.toNumber = '',
    this.recipient,
    this.lookingUp = false,
    this.recipientError,
    this.amountCents = 0,
    this.description = '',
    this.idempotencyKey,
    this.receipt,
    this.failure,
    this.attempts = 0,
  });

  final TransferStep step;
  final String? fromAccountId;
  final String toNumber;
  final RecipientInfo? recipient;
  final bool lookingUp;
  final String? recipientError;
  final int amountCents;
  final String description;

  /// Una clave por intención de pago: se conserva en reintentos y se descarta si cambian los datos.
  final String? idempotencyKey;
  final TransferReceipt? receipt;
  final AppFailure? failure;
  final int attempts;

  TransferState copyWith({
    TransferStep? step,
    String? fromAccountId,
    String? toNumber,
    RecipientInfo? recipient,
    bool clearRecipient = false,
    bool? lookingUp,
    String? recipientError,
    bool clearRecipientError = false,
    int? amountCents,
    String? description,
    String? idempotencyKey,
    bool clearKey = false,
    TransferReceipt? receipt,
    AppFailure? failure,
    bool clearFailure = false,
    int? attempts,
  }) => TransferState(
    step: step ?? this.step,
    fromAccountId: fromAccountId ?? this.fromAccountId,
    toNumber: toNumber ?? this.toNumber,
    recipient: clearRecipient ? null : (recipient ?? this.recipient),
    lookingUp: lookingUp ?? this.lookingUp,
    recipientError: clearRecipientError ? null : (recipientError ?? this.recipientError),
    amountCents: amountCents ?? this.amountCents,
    description: description ?? this.description,
    idempotencyKey: clearKey ? null : (idempotencyKey ?? this.idempotencyKey),
    receipt: receipt ?? this.receipt,
    failure: clearFailure ? null : (failure ?? this.failure),
    attempts: attempts ?? this.attempts,
  );

  @override
  List<Object?> get props => [
    step,
    fromAccountId,
    toNumber,
    recipient?.number,
    lookingUp,
    recipientError,
    amountCents,
    description,
    idempotencyKey,
    receipt?.id,
    failure,
    attempts,
  ];
}

class TransferCubit extends Cubit<TransferState> {
  TransferCubit({
    required TransfersRepository transfers,
    required AccountsRepository accounts,
    required Telemetry telemetry,
    String? initialFrom,
    String Function()? keyFactory,
  }) : _transfers = transfers,
       _accounts = accounts,
       _telemetry = telemetry,
       _newKey = keyFactory ?? (() => const Uuid().v4()),
       super(TransferState(fromAccountId: initialFrom));

  final TransfersRepository _transfers;
  final AccountsRepository _accounts;
  final Telemetry _telemetry;
  final String Function() _newKey;

  void selectFrom(String id) => emit(state.copyWith(fromAccountId: id, clearKey: true));

  Future<void> setDestination(String number) async {
    emit(state.copyWith(toNumber: number, clearRecipient: true, clearRecipientError: true, clearKey: true));
    if (number.length != 10) return;
    emit(state.copyWith(lookingUp: true));
    try {
      final r = await _accounts.lookup(number);
      if (state.toNumber == number) emit(state.copyWith(recipient: r, lookingUp: false));
    } on AppFailure catch (f) {
      if (state.toNumber == number) emit(state.copyWith(lookingUp: false, recipientError: f.message));
    }
  }

  /// Pasa a confirmación. [availableCents] permite validar fondos antes de ir al servidor.
  void review({required int amountCents, required String description, required int availableCents}) {
    if (state.fromAccountId == null || state.recipient == null || amountCents <= 0) return;
    if (amountCents > availableCents) {
      emit(state.copyWith(failure: const BusinessFailure('Saldo insuficiente', code: 'INSUFFICIENT_FUNDS')));
      return;
    }
    emit(
      state.copyWith(
        step: TransferStep.confirm,
        amountCents: amountCents,
        description: description,
        idempotencyKey: state.idempotencyKey ?? _newKey(),
        clearFailure: true,
      ),
    );
    _telemetry.event('transfer_review');
  }

  void edit() => emit(state.copyWith(step: TransferStep.form, clearKey: true, clearFailure: true));

  Future<void> confirm() async {
    if (state.step == TransferStep.processing || state.idempotencyKey == null) return;
    emit(state.copyWith(step: TransferStep.processing, clearFailure: true, attempts: state.attempts + 1));
    final sw = Stopwatch()..start();
    try {
      final receipt = await _transfers.transfer(
        idempotencyKey: state.idempotencyKey!,
        fromAccountId: state.fromAccountId!,
        toAccountNumber: state.toNumber,
        amountCents: state.amountCents,
        description: state.description,
      );
      _telemetry.event('transfer_success', {'attempts': state.attempts, 'ms': sw.elapsedMilliseconds});
      emit(state.copyWith(step: TransferStep.success, receipt: receipt));
    } on AppFailure catch (f) {
      _telemetry.event('transfer_failed', {'type': f.runtimeType.toString(), 'attempts': state.attempts});
      // Falla transitoria: el resultado es incierto. Reintentar con la MISMA clave es seguro.
      emit(state.copyWith(step: f.isTransient ? TransferStep.uncertain : TransferStep.rejected, failure: f));
    }
  }
}
