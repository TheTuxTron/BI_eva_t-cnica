import '../../../core/network/api_client.dart';
import '../../../core/utils/formatters.dart';

class TransferReceipt {
  const TransferReceipt({required this.id, required this.amountCents, required this.toMaskedNumber, required this.createdAt, this.replayed = false});
  factory TransferReceipt.fromJson(Map<String, dynamic> j) => TransferReceipt(
        id: j['id'] as String,
        amountCents: (j['amountCents'] as num).toInt(),
        toMaskedNumber: j['toMaskedNumber'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
  final String id;
  final int amountCents;
  final String toMaskedNumber;
  final DateTime createdAt;
  final bool replayed;
}

class TransfersRepository {
  TransfersRepository(this.api);
  final ApiClient api;

  /// La misma [idempotencyKey] en reintentos garantiza un único débito.
  Future<TransferReceipt> transfer({
    required String idempotencyKey,
    required String fromAccountId,
    required String toAccountNumber,
    required int amountCents,
    String? description,
  }) async {
    final j = await api.post<Json>(
      '/v1/transfers',
      headers: {'Idempotency-Key': idempotencyKey},
      body: {
        'fromAccountId': fromAccountId,
        'toAccountNumber': toAccountNumber,
        'amount': Money.toApi(amountCents),
        if (description != null && description.trim().isNotEmpty) 'description': description.trim(),
      },
    );
    return TransferReceipt.fromJson(j);
  }
}
