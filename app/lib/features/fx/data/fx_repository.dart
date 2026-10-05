import '../../../core/cache/cache_store.dart';
import '../../../core/cache/resource.dart';
import '../../../core/network/api_client.dart';

class FxRates {
  const FxRates({required this.base, required this.date, required this.rates, required this.serverStale});
  factory FxRates.fromJson(Object? json) {
    final j = Map<String, dynamic>.from(json! as Map);
    return FxRates(
      base: j['base'] as String,
      date: j['date'] as String,
      rates: Map<String, dynamic>.from(j['rates'] as Map).map((k, v) => MapEntry(k, (v as num).toDouble())),
      serverStale: (j['stale'] as bool?) ?? false,
    );
  }
  final String base, date;
  final Map<String, double> rates;

  /// El BFF también puede servir datos vencidos si el proveedor externo está caído.
  final bool serverStale;
}

class FxRepository {
  FxRepository(this.api, this.cache);
  final ApiClient api;
  final CacheStore cache;

  Stream<Resource<FxRates>> watchRates() =>
      staleWhileRevalidate(cache: cache, key: 'fx', fetch: () => api.get<Json>('/v1/fx/rates'), decode: FxRates.fromJson);
}
