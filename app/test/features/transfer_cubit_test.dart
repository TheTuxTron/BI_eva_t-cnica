import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinti/core/network/failures.dart';
import 'package:kinti/features/accounts/data/accounts_repository.dart';
import 'package:kinti/features/transfers/data/transfers_repository.dart';
import 'package:kinti/features/transfers/presentation/transfer_cubit.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fakes.dart';

class MockTransfers extends Mock implements TransfersRepository {}

class MockAccounts extends Mock implements AccountsRepository {}

void main() {
  late MockTransfers transfers;
  late MockAccounts accounts;
  final receipt = TransferReceipt(id: 'trf_1', amountCents: 1250, toMaskedNumber: '****0011', createdAt: DateTime(2026, 10, 3));
  const recipient = RecipientInfo(number: '2200990011', holder: 'María Y.', type: 'savings');

  setUp(() {
    transfers = MockTransfers();
    accounts = MockAccounts();
    when(() => accounts.lookup('2200990011')).thenAnswer((_) async => recipient);
  });

  var keys = 0;
  TransferCubit build() => TransferCubit(
        transfers: transfers,
        accounts: accounts,
        telemetry: FakeTelemetry(),
        initialFrom: 'acc_1',
        keyFactory: () => 'key-${++keys}',
      );

  Future<void> fillAndReview(TransferCubit c) async {
    await c.setDestination('2200990011');
    c.review(amountCents: 1250, description: 'Almuerzo', availableCents: 10000);
  }

  When<Future<TransferReceipt>> stubTransfer() => when(() => transfers.transfer(
        idempotencyKey: any(named: 'idempotencyKey'),
        fromAccountId: any(named: 'fromAccountId'),
        toAccountNumber: any(named: 'toAccountNumber'),
        amountCents: any(named: 'amountCents'),
        description: any(named: 'description'),
      ));

  test('verifica el destinatario y genera una clave de idempotencia al revisar', () async {
    final c = build();
    await fillAndReview(c);
    expect(c.state.recipient?.holder, 'María Y.');
    expect(c.state.step, TransferStep.confirm);
    expect(c.state.idempotencyKey, isNotNull);
  });

  test('saldo insuficiente se detecta antes de llamar al servidor', () async {
    final c = build();
    await c.setDestination('2200990011');
    c.review(amountCents: 99999, description: '', availableCents: 100);
    expect(c.state.step, TransferStep.form);
    expect(c.state.failure, isA<BusinessFailure>());
  });

  test('falla transitoria → estado incierto; el reintento usa LA MISMA clave', () async {
    var call = 0;
    stubTransfer().thenAnswer((_) async {
      call++;
      if (call == 1) throw const TimeoutFailure();
      return receipt;
    });
    final c = build();
    await fillAndReview(c);
    await c.confirm();
    expect(c.state.step, TransferStep.uncertain);
    await c.confirm();
    expect(c.state.step, TransferStep.success);

    final captured = verify(() => transfers.transfer(
          idempotencyKey: captureAny(named: 'idempotencyKey'),
          fromAccountId: any(named: 'fromAccountId'),
          toAccountNumber: any(named: 'toAccountNumber'),
          amountCents: any(named: 'amountCents'),
          description: any(named: 'description'),
        )).captured;
    expect(captured, hasLength(2));
    expect(captured.toSet(), hasLength(1));
  });

  test('editar los datos descarta la clave (es otra intención de pago)', () async {
    final c = build();
    await fillAndReview(c);
    final first = c.state.idempotencyKey;
    c.edit();
    c.review(amountCents: 2000, description: '', availableCents: 10000);
    expect(c.state.idempotencyKey, isNot(first));
  });

  blocTest<TransferCubit, TransferState>(
    'error de negocio → rechazado (no se ofrece reintentar)',
    build: build,
    setUp: () => stubTransfer().thenThrow(const BusinessFailure('Superas tu límite diario', code: 'DAILY_LIMIT')),
    act: (c) async {
      await fillAndReview(c);
      await c.confirm();
    },
    verify: (c) {
      expect(c.state.step, TransferStep.rejected);
      expect(c.state.failure?.message, contains('límite'));
    },
  );
}
