import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/cache/resource.dart';
import '../data/accounts_repository.dart';

/// Saldos consolidados. Vive a nivel del shell autenticado: lo comparten Inicio,
/// Cuentas y Transferencias, y se refresca tras cada transferencia.
class AccountsCubit extends Cubit<Resource<AccountsSnapshot>> {
  AccountsCubit(this._repo) : super(const Resource.loading());
  final AccountsRepository _repo;
  StreamSubscription<Resource<AccountsSnapshot>>? _sub;

  Future<void> load() async {
    await _sub?.cancel();
    final done = Completer<void>();
    _sub = _repo.watchAccounts().listen(
      emit,
      onDone: () {
        if (!done.isCompleted) done.complete();
      },
    );
    return done.future;
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
