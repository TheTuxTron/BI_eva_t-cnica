import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/failures.dart';
import '../data/notifications_repository.dart';

class NotificationsState extends Equatable {
  const NotificationsState({this.items = const [], this.unread = 0, this.loading = true, this.failure, this.fromCache = false});
  final List<AppNotification> items;
  final int unread;
  final bool loading;
  final AppFailure? failure;
  final bool fromCache;
  @override
  List<Object?> get props => [items, unread, loading, failure, fromCache];
}

class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit(this._repo) : super(const NotificationsState());
  final NotificationsRepository _repo;
  StreamSubscription<Object?>? _sub;

  Future<void> refresh() async {
    await _sub?.cancel();
    final done = Completer<void>();
    _sub = _repo.watchInbox().listen((r) {
      emit(NotificationsState(
        items: r.data?.items ?? state.items,
        unread: r.data?.unread ?? state.unread,
        loading: r.isInitialLoading,
        failure: r.error,
        fromCache: r.fromCache,
      ));
    }, onDone: () {
      if (!done.isCompleted) done.complete();
    });
    return done.future;
  }

  /// Llega una notificación en primer plano: se agrega sin esperar al servidor.
  void received(AppNotification n) {
    if (state.items.any((i) => i.id == n.id)) return;
    emit(NotificationsState(items: [n, ...state.items], unread: state.unread + 1, loading: false, fromCache: state.fromCache));
  }

  Future<void> markRead(AppNotification n) async {
    if (n.read) return;
    emit(NotificationsState(
      items: [for (final i in state.items) i.id == n.id ? i.markRead() : i],
      unread: state.unread > 0 ? state.unread - 1 : 0,
      loading: false,
    ));
    try {
      await _repo.markRead(n.id);
    } catch (_) {/* se reconcilia en el próximo refresh */}
  }

  Future<void> markAllRead() async {
    emit(NotificationsState(items: [for (final i in state.items) i.markRead()], unread: 0, loading: false));
    try {
      await _repo.markAllRead();
    } catch (_) {}
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
