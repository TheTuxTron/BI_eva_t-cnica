import 'package:flutter_test/flutter_test.dart';
import 'package:kinti/core/cache/resource.dart';
import 'package:kinti/core/network/failures.dart';
import 'package:kinti/features/accounts/data/accounts_repository.dart';
import 'package:kinti/features/accounts/presentation/movements_cubit.dart';
import 'package:mocktail/mocktail.dart';

class MockAccounts extends Mock implements AccountsRepository {}

Movement _m(String id) => Movement(
  id: id,
  amountCents: -100,
  balanceAfterCents: 1000,
  description: 'x',
  category: 'compras',
  createdAt: DateTime(2026, 10, 1),
);

void main() {
  late MockAccounts repo;
  setUp(() => repo = MockAccounts());

  test('carga la primera página y pagina por cursor hasta el final', () async {
    when(() => repo.watchFirstPage('a1', category: null)).thenAnswer(
      (_) => Stream<Resource<MovementsPage>>.fromIterable([
        const Resource.loading(),
        Resource(data: MovementsPage([_m('1'), _m('2')], 'c1')),
      ]),
    );
    when(() => repo.nextPage('a1', 'c1', category: null)).thenAnswer((_) async => MovementsPage([_m('3')], null));

    final c = MovementsCubit(repo, accountId: 'a1');
    await c.load();
    expect(c.state.items.map((e) => e.id), ['1', '2']);
    expect(c.state.hasMore, isTrue);
    await c.loadMore();
    expect(c.state.items.map((e) => e.id), ['1', '2', '3']);
    expect(c.state.hasMore, isFalse);
  });

  test('si falla "cargar más" se conservan los movimientos ya mostrados', () async {
    when(
      () => repo.watchFirstPage('a1', category: null),
    ).thenAnswer((_) => Stream<Resource<MovementsPage>>.value(Resource(data: MovementsPage([_m('1')], 'c1'))));
    when(() => repo.nextPage('a1', 'c1', category: null)).thenThrow(const NetworkFailure());
    final c = MovementsCubit(repo, accountId: 'a1');
    await c.load();
    await c.loadMore();
    expect(c.state.items, hasLength(1));
    expect(c.state.loadMoreFailure, isA<NetworkFailure>());
    expect(c.state.hasMore, isTrue);
  });

  test('desde caché offline no intenta paginar', () async {
    when(() => repo.watchFirstPage('a1', category: null)).thenAnswer(
      (_) => Stream<Resource<MovementsPage>>.value(
        Resource(data: MovementsPage([_m('1')], 'c1'), fromCache: true, error: const NetworkFailure()),
      ),
    );
    final c = MovementsCubit(repo, accountId: 'a1');
    await c.load();
    await c.loadMore();
    verifyNever(() => repo.nextPage(any(), any(), category: any(named: 'category')));
  });
}
