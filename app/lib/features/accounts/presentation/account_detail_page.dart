import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di.dart';
import '../../../core/utils/formatters.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/widgets.dart';
import '../data/accounts_repository.dart';
import 'account_widgets.dart';
import 'accounts_cubit.dart';
import 'movements_cubit.dart';

class AccountDetailPage extends StatelessWidget {
  const AccountDetailPage({super.key, required this.accountId, this.category});
  final String accountId;
  final String? category;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => MovementsCubit(sl<AccountsRepository>(), accountId: accountId, category: category)..load(),
    child: _DetailView(accountId: accountId, category: category),
  );
}

class _DetailView extends StatefulWidget {
  const _DetailView({required this.accountId, this.category});
  final String accountId;
  final String? category;
  @override
  State<_DetailView> createState() => _DetailViewState();
}

class _DetailViewState extends State<_DetailView> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) context.read<MovementsCubit>().loadMore();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final account = context.select(
      (AccountsCubit c) =>
          firstWhereOrNull(c.state.data?.items ?? const <Account>[], (Account a) => a.id == widget.accountId),
    );
    return Scaffold(
      appBar: AppBar(title: Text(account?.alias ?? 'Movimientos')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('detail_transfer'),
        onPressed: () => context.push('/transfer?from=${widget.accountId}'),
        icon: const Icon(Icons.swap_horiz_rounded),
        label: const Text('Transferir'),
      ),
      body: BlocBuilder<MovementsCubit, MovementsState>(
        builder: (context, s) {
          return RefreshIndicator(
            onRefresh: () async {
              await Future.wait([context.read<MovementsCubit>().load(), context.read<AccountsCubit>().load()]);
            },
            child: CustomScrollView(
              controller: _scroll,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(KSpace.md, 0, KSpace.md, KSpace.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (account != null) ...[
                          AccountNumberText(account: account, style: Theme.of(context).textTheme.bodyMedium),
                          AmountText(
                            account.balanceCents,
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: KSpace.sm),
                        ],
                        if (widget.category != null)
                          Chip(
                            avatar: Icon(categoryOf(widget.category!).$2, size: 18),
                            label: Text('Solo ${categoryOf(widget.category!).$1.toLowerCase()}'),
                          ),
                        if (s.fromCache || (s.failure != null && s.items.isNotEmpty))
                          StaleNotice(updatedAt: s.updatedAt, onRetry: () => context.read<MovementsCubit>().load()),
                      ],
                    ),
                  ),
                ),
                if (s.initialLoading && s.items.isEmpty)
                  SliverList.separated(
                    itemCount: 6,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder:
                        (_, __) => const Padding(
                          padding: EdgeInsets.symmetric(horizontal: KSpace.md),
                          child: Skeleton(height: 48),
                        ),
                  )
                else if (s.failure != null && s.items.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: ErrorView(failure: s.failure!, onRetry: () => context.read<MovementsCubit>().load()),
                    ),
                  )
                else if (s.items.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text('Aún no tienes movimientos')),
                  )
                else
                  ..._grouped(context, s),
                SliverToBoxAdapter(child: _footer(context, s)),
                const SliverToBoxAdapter(child: SizedBox(height: 96)),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _grouped(BuildContext context, MovementsState s) {
    final out = <Widget>[];
    String? current;
    final buffer = <Movement>[];
    void flush() {
      if (buffer.isEmpty) return;
      final items = List<Movement>.of(buffer);
      out.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(KSpace.md, KSpace.md, KSpace.md, KSpace.xs),
            child: Semantics(header: true, child: Text(current!, style: Theme.of(context).textTheme.labelLarge)),
          ),
        ),
      );
      out.add(SliverList.builder(itemCount: items.length, itemBuilder: (_, i) => MovementTile(movement: items[i])));
      buffer.clear();
    }

    for (final m in s.items) {
      final header = Dates.dayHeader(m.createdAt);
      if (header != current) {
        flush();
        current = header;
      }
      buffer.add(m);
    }
    flush();
    return out;
  }

  Widget _footer(BuildContext context, MovementsState s) {
    if (s.loadingMore) {
      return const Padding(padding: EdgeInsets.all(KSpace.md), child: Center(child: CircularProgressIndicator()));
    }
    if (s.loadMoreFailure != null) {
      return ErrorView(
        failure: s.loadMoreFailure!,
        compact: true,
        onRetry: () => context.read<MovementsCubit>().loadMore(),
      );
    }
    if (s.fromCache && s.hasMore) {
      return const Padding(
        padding: EdgeInsets.all(KSpace.md),
        child: Center(child: Text('Conéctate para ver movimientos anteriores')),
      );
    }
    return const SizedBox.shrink();
  }
}
