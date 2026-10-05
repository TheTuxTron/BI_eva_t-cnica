import 'package:equatable/equatable.dart';

import '../../../core/cache/cache_store.dart';
import '../../../core/cache/resource.dart';
import '../../../core/network/api_client.dart';

class Account extends Equatable {
  const Account({
    required this.id,
    required this.type,
    required this.number,
    required this.maskedNumber,
    required this.alias,
    required this.balanceCents,
    this.currency = 'USD',
  });
  factory Account.fromJson(Map<String, dynamic> j) => Account(
    id: j['id'] as String,
    type: j['type'] as String,
    number: j['number'] as String,
    maskedNumber: j['maskedNumber'] as String,
    alias: j['alias'] as String,
    balanceCents: (j['balanceCents'] as num).toInt(),
    currency: (j['currency'] as String?) ?? 'USD',
  );
  final String id, type, number, maskedNumber, alias, currency;
  final int balanceCents;
  String get typeLabel => type == 'checking' ? 'Corriente' : 'Ahorros';
  @override
  List<Object?> get props => [id, balanceCents, alias];
}

class AccountsSnapshot extends Equatable {
  const AccountsSnapshot({required this.items, required this.totalCents});
  factory AccountsSnapshot.fromJson(Object? json) {
    final j = Map<String, dynamic>.from(json! as Map);
    return AccountsSnapshot(
      items: (j['items'] as List).map((e) => Account.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      totalCents: (j['totalCents'] as num).toInt(),
    );
  }
  final List<Account> items;
  final int totalCents;
  @override
  List<Object?> get props => [items, totalCents];
}

class Movement extends Equatable {
  const Movement({
    required this.id,
    required this.amountCents,
    required this.balanceAfterCents,
    required this.description,
    required this.category,
    required this.createdAt,
  });
  factory Movement.fromJson(Map<String, dynamic> j) => Movement(
    id: j['id'] as String,
    amountCents: (j['amountCents'] as num).toInt(),
    balanceAfterCents: (j['balanceAfterCents'] as num).toInt(),
    description: j['description'] as String,
    category: j['category'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
  );
  final String id, description, category;
  final int amountCents, balanceAfterCents;
  final DateTime createdAt;
  @override
  List<Object?> get props => [id];
}

class MovementsPage {
  const MovementsPage(this.items, this.nextCursor);
  factory MovementsPage.fromJson(Object? json) {
    final j = Map<String, dynamic>.from(json! as Map);
    return MovementsPage(
      (j['items'] as List).map((e) => Movement.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      j['nextCursor'] as String?,
    );
  }
  final List<Movement> items;
  final String? nextCursor;
}

class RecipientInfo {
  const RecipientInfo({required this.number, required this.holder, required this.type});
  final String number, holder, type;
}

class AccountsRepository {
  AccountsRepository(this.api, this.cache);
  final ApiClient api;
  final CacheStore cache;

  Stream<Resource<AccountsSnapshot>> watchAccounts() => staleWhileRevalidate(
    cache: cache,
    key: 'accounts',
    fetch: () => api.get<Json>('/v1/accounts'),
    decode: AccountsSnapshot.fromJson,
  );

  /// Solo la primera página se cachea (lo que el usuario ve al abrir offline).
  Stream<Resource<MovementsPage>> watchFirstPage(String accountId, {String? category}) => staleWhileRevalidate(
    cache: cache,
    key: 'movements:$accountId:${category ?? 'all'}',
    fetch:
        () => api.get<Json>(
          '/v1/accounts/$accountId/movements',
          query: {'limit': 20, if (category != null) 'category': category},
        ),
    decode: MovementsPage.fromJson,
  );

  Future<MovementsPage> nextPage(String accountId, String cursor, {String? category}) async {
    final j = await api.get<Json>(
      '/v1/accounts/$accountId/movements',
      query: {'limit': 20, 'cursor': cursor, if (category != null) 'category': category},
    );
    return MovementsPage.fromJson(j);
  }

  Future<RecipientInfo> lookup(String number) async {
    final j = await api.get<Json>('/v1/accounts/lookup', query: {'number': number});
    return RecipientInfo(number: j['number'] as String, holder: j['holder'] as String, type: j['type'] as String);
  }
}
