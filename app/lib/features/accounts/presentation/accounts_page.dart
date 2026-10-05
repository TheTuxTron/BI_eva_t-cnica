import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/cache/resource.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/widgets.dart';
import '../data/accounts_repository.dart';
import 'account_widgets.dart';
import 'accounts_cubit.dart';

class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key, this.category});
  final String? category;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis cuentas')),
      body: BlocBuilder<AccountsCubit, Resource<AccountsSnapshot>>(
        builder: (context, r) {
          if (r.isInitialLoading) {
            return ListView(
              padding: const EdgeInsets.all(KSpace.md),
              children: const [
                Skeleton(height: 72, radius: KRadius.card),
                SizedBox(height: KSpace.sm),
                Skeleton(height: 72, radius: KRadius.card),
              ],
            );
          }
          if (r.isFatal) {
            return Center(child: ErrorView(failure: r.error!, onRetry: () => context.read<AccountsCubit>().load()));
          }
          final items = r.data!.items;
          return RefreshIndicator(
            onRefresh: () => context.read<AccountsCubit>().load(),
            child: ListView(
              padding: const EdgeInsets.all(KSpace.md),
              children: [
                if (r.isStale) ...[StaleNotice(updatedAt: r.updatedAt), const SizedBox(height: KSpace.md)],
                if (category != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: KSpace.md),
                    child: Text('Elige una cuenta para ver tus gastos en ${categoryOf(category!).$1.toLowerCase()}'),
                  ),
                for (final a in items) ...[
                  AccountTile(account: a, category: category),
                  const SizedBox(height: KSpace.sm),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
