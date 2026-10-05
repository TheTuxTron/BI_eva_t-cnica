import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/failures.dart';
import '../data/accounts_repository.dart';

class MovementsState extends Equatable {
  const MovementsState({
    this.items = const [],
    this.nextCursor,
    this.initialLoading = true,
    this.loadingMore = false,
    this.failure,
    this.loadMoreFailure,
    this.fromCache = false,
    this.updatedAt,
  });
  final List<Movement> items;
  final String? nextCursor;
  final bool initialLoading;
  final bool loadingMore;
  final AppFailure? failure;
  final AppFailure? loadMoreFailure;
  final bool fromCache;
  final DateTime? updatedAt;

  bool get hasMore => nextCursor != null;

  MovementsState copyWith({
    List<Movement>? items,
    String? nextCursor,
    bool clearCursor = false,
    bool? initialLoading,
    bool? loadingMore,
    AppFailure? failure,
    bool clearFailure = false,
    AppFailure? loadMoreFailure,
    bool clearLoadMoreFailure = false,
    bool? fromCache,
    DateTime? updatedAt,
  }) => MovementsState(
    items: items ?? this.items,
    nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
    initialLoading: initialLoading ?? this.initialLoading,
    loadingMore: loadingMore ?? this.loadingMore,
    failure: clearFailure ? null : (failure ?? this.failure),
    loadMoreFailure: clearLoadMoreFailure ? null : (loadMoreFailure ?? this.loadMoreFailure),
    fromCache: fromCache ?? this.fromCache,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  List<Object?> get props => [
    items,
    nextCursor,
    initialLoading,
    loadingMore,
    failure,
    loadMoreFailure,
    fromCache,
    updatedAt,
  ];
}

/// Historial paginado (cursor). La primera página sale de caché si no hay red;
/// un fallo al cargar más páginas no borra lo ya mostrado.
class MovementsCubit extends Cubit<MovementsState> {
  MovementsCubit(this._repo, {required this.accountId, this.category}) : super(const MovementsState());
  final AccountsRepository _repo;
  final String accountId;
  final String? category;
  StreamSubscription<Object?>? _sub;

  Future<void> load() async {
    await _sub?.cancel();
    final done = Completer<void>();
    emit(state.copyWith(initialLoading: true, clearFailure: true));
    _sub = _repo
        .watchFirstPage(accountId, category: category)
        .listen(
          (r) {
            emit(
              MovementsState(
                items: r.data?.items ?? state.items,
                nextCursor: r.data?.nextCursor,
                initialLoading: r.isRefreshing && r.data == null,
                failure: r.error,
                fromCache: r.fromCache,
                updatedAt: r.updatedAt,
              ),
            );
          },
          onDone: () {
            if (!done.isCompleted) done.complete();
          },
        );
    return done.future;
  }

  Future<void> loadMore() async {
    final cursor = state.nextCursor;
    if (cursor == null || state.loadingMore || state.fromCache) return;
    emit(state.copyWith(loadingMore: true, clearLoadMoreFailure: true));
    try {
      final page = await _repo.nextPage(accountId, cursor, category: category);
      emit(
        state.copyWith(
          items: [...state.items, ...page.items],
          nextCursor: page.nextCursor,
          clearCursor: page.nextCursor == null,
          loadingMore: false,
        ),
      );
    } on AppFailure catch (f) {
      emit(state.copyWith(loadingMore: false, loadMoreFailure: f));
    }
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
