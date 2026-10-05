import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/deep_links.dart';
import '../../../app/di.dart';
import '../../../core/utils/formatters.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/widgets.dart';
import 'notifications_cubit.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones'), actions: [
        TextButton(onPressed: () => context.read<NotificationsCubit>().markAllRead(), child: const Text('Marcar todo leído')),
      ]),
      body: BlocBuilder<NotificationsCubit, NotificationsState>(
        builder: (context, s) {
          if (s.loading && s.items.isEmpty) return const Center(child: CircularProgressIndicator());
          if (s.failure != null && s.items.isEmpty) {
            return Center(child: ErrorView(failure: s.failure!, onRetry: () => context.read<NotificationsCubit>().refresh()));
          }
          return RefreshIndicator(
            onRefresh: () => context.read<NotificationsCubit>().refresh(),
            child: s.items.isEmpty
                ? ListView(children: const [SizedBox(height: 120), Center(child: Text('No tienes notificaciones'))])
                : ListView.separated(
                    padding: const EdgeInsets.all(KSpace.md),
                    itemCount: s.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: KSpace.sm),
                    itemBuilder: (context, i) {
                      final n = s.items[i];
                      return KCard(
                        onTap: () {
                          context.read<NotificationsCubit>().markRead(n);
                          if (n.deeplink != null) sl<DeepLinks>().open(context, n.deeplink!, source: 'inbox');
                        },
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Semantics(
                              label: n.read ? 'Leída' : 'No leída',
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: n.read ? Colors.transparent : Theme.of(context).colorScheme.primary),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(n.title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: n.read ? FontWeight.w500 : FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text(n.body),
                              const SizedBox(height: 4),
                              Text(Dates.ago(n.createdAt), style: Theme.of(context).textTheme.bodySmall),
                            ]),
                          ),
                        ]),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}
