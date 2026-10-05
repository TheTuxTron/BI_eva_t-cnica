import 'package:equatable/equatable.dart';

import '../network/failures.dart';
import 'cache_store.dart';

/// Estado de un dato remoto con soporte offline:
/// - data + isRefreshing: mostrando caché mientras se actualiza
/// - data + error: mostrando caché vieja porque la red falló (degradado, no roto)
/// - error sin data: único caso que muestra pantalla de error
class Resource<T> extends Equatable {
  const Resource({this.data, this.error, this.isRefreshing = false, this.updatedAt, this.fromCache = false});

  const Resource.loading() : this(isRefreshing: true);

  final T? data;
  final AppFailure? error;
  final bool isRefreshing;
  final DateTime? updatedAt;
  final bool fromCache;

  bool get hasData => data != null;
  bool get isInitialLoading => data == null && isRefreshing;
  bool get isStale => hasData && (fromCache || error != null);
  bool get isFatal => data == null && error != null && !isRefreshing;

  Resource<T> copyWith({T? data, AppFailure? error, bool clearError = false, bool? isRefreshing, DateTime? updatedAt, bool? fromCache}) =>
      Resource<T>(
        data: data ?? this.data,
        error: clearError ? null : (error ?? this.error),
        isRefreshing: isRefreshing ?? this.isRefreshing,
        updatedAt: updatedAt ?? this.updatedAt,
        fromCache: fromCache ?? this.fromCache,
      );

  @override
  List<Object?> get props => [data, error, isRefreshing, updatedAt, fromCache];
}

/// Stale-while-revalidate: emite primero la caché (instantáneo, funciona offline) y luego
/// el dato fresco. Si la red falla, conserva la caché y adjunta el error.
Stream<Resource<T>> staleWhileRevalidate<T>({
  required CacheStore cache,
  required String key,
  required Future<Object?> Function() fetch,
  required T Function(Object? json) decode,
}) async* {
  final cached = cache.read(key);
  T? cachedData;
  if (cached != null) {
    try {
      cachedData = decode(cached.data);
    } catch (_) {
      cachedData = null; // caché corrupta o de un esquema anterior: se ignora
    }
  }
  yield Resource<T>(data: cachedData, isRefreshing: true, updatedAt: cached?.storedAt, fromCache: cachedData != null);
  try {
    final json = await fetch();
    final fresh = decode(json);
    await cache.write(key, json);
    yield Resource<T>(data: fresh, updatedAt: DateTime.now());
  } catch (e) {
    yield Resource<T>(data: cachedData, error: AppFailure.from(e), updatedAt: cached?.storedAt, fromCache: cachedData != null);
  }
}
