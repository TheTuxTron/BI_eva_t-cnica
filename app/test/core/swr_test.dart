import 'package:flutter_test/flutter_test.dart';
import 'package:kinti/core/cache/cache_store.dart';
import 'package:kinti/core/cache/resource.dart';
import 'package:kinti/core/network/failures.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late CacheStore cache;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    cache = CacheStore(await SharedPreferences.getInstance())..setNamespace('u1');
  });

  int decode(Object? j) => (j! as Map)['v'] as int;

  test('sin caché: loading → dato fresco, y lo persiste', () async {
    final states =
        await staleWhileRevalidate(cache: cache, key: 'k', fetch: () async => {'v': 1}, decode: decode).toList();
    expect(states.first.isInitialLoading, isTrue);
    expect(states.last.data, 1);
    expect(states.last.isStale, isFalse);
    expect(cache.read('k')!.data, {'v': 1});
  });

  test('con caché y red caída: muestra caché marcada como desactualizada', () async {
    await cache.write('k', {'v': 7});
    final states =
        await staleWhileRevalidate<int>(
          cache: cache,
          key: 'k',
          fetch: () async => throw const NetworkFailure(),
          decode: decode,
        ).toList();
    expect(states.first.data, 7);
    expect(states.first.isRefreshing, isTrue);
    expect(states.last.data, 7);
    expect(states.last.error, isA<NetworkFailure>());
    expect(states.last.isStale, isTrue);
    expect(states.last.isFatal, isFalse);
  });

  test('sin caché y red caída: error fatal (única situación con pantalla de error)', () async {
    final last =
        await staleWhileRevalidate<int>(
          cache: cache,
          key: 'k',
          fetch: () async => throw const TimeoutFailure(),
          decode: decode,
        ).last;
    expect(last.isFatal, isTrue);
  });

  test('caché corrupta se ignora sin romper', () async {
    await cache.write('k', {'otro': 'formato'});
    final states =
        await staleWhileRevalidate(cache: cache, key: 'k', fetch: () async => {'v': 2}, decode: decode).toList();
    expect(states.first.data, isNull);
    expect(states.last.data, 2);
  });

  test('la caché está aislada por usuario y se limpia al cerrar sesión', () async {
    await cache.write('accounts', {'v': 1});
    cache.setNamespace('u2');
    expect(cache.read('accounts'), isNull);
    cache.setNamespace('u1');
    await cache.clearAll();
    expect(cache.read('accounts'), isNull);
  });
}
