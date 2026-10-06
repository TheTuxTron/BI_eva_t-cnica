import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/cache/resource.dart';
import '../../../core/utils/formatters.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/widgets.dart';
import '../../../sdui/sdui_models.dart';
import '../data/accounts_repository.dart';
import 'accounts_cubit.dart';
import 'package:flutter/services.dart';

const kCategories = <String, (String, IconData)>{
  'alimentacion': ('Supermercado', Icons.shopping_basket_outlined),
  'restaurantes': ('Restaurantes', Icons.restaurant_outlined),
  'transporte': ('Transporte', Icons.directions_bus_outlined),
  'servicios': ('Servicios', Icons.bolt_outlined),
  'compras': ('Compras', Icons.shopping_bag_outlined),
  'salud': ('Salud', Icons.local_pharmacy_outlined),
  'entretenimiento': ('Entretenimiento', Icons.movie_outlined),
  'ingresos': ('Ingresos', Icons.south_west_rounded),
  'transferencias': ('Transferencias', Icons.swap_horiz_rounded),
};

(String, IconData) categoryOf(String c) => kCategories[c] ?? (c, Icons.receipt_outlined);

/// Componente SDUI "account_summary": el elemento protagonista del inicio.
class AccountSummaryComponent extends StatefulWidget {
  const AccountSummaryComponent({super.key, required this.section});
  final SduiSection section;
  @override
  State<AccountSummaryComponent> createState() => _AccountSummaryComponentState();
}

class _AccountSummaryComponentState extends State<AccountSummaryComponent> {
  late bool _visible = widget.section.flag('balanceVisible', fallback: true);

  @override
  Widget build(BuildContext context) {
    final brand = KBrand.of(context);
    return BlocBuilder<AccountsCubit, Resource<AccountsSnapshot>>(
      builder: (context, r) {
        if (r.isFatal) {
          return KCard(
            child: ErrorView(failure: r.error!, compact: true, onRetry: () => context.read<AccountsCubit>().load()),
          );
        }
        final snap = r.data;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(KSpace.lg),
              decoration: BoxDecoration(gradient: brand.hero, borderRadius: BorderRadius.circular(KRadius.hero)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 18,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(color: brand.heroAccent, borderRadius: BorderRadius.circular(2)),
                      ),
                      Expanded(
                        child: Text(
                          'Saldo disponible',
                          style: TextStyle(color: brand.onHeroMuted, fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        key: const Key('toggle_balance'),
                        tooltip: _visible ? 'Ocultar saldos' : 'Mostrar saldos',
                        color: brand.onHero,
                        icon: Icon(_visible ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _visible = !_visible),
                      ),
                    ],
                  ),
                  if (snap == null)
                    const Skeleton(height: 40, width: 200)
                  else
                    AmountText(
                      snap.totalCents,
                      hidden: !_visible,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: brand.onHero,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                  if (snap != null && snap.items.length > 1)
                    Text('${snap.items.length} cuentas', style: TextStyle(color: brand.onHeroMuted)),
                ],
              ),
            ),
            if (r.isStale) ...[
              const SizedBox(height: KSpace.sm),
              StaleNotice(updatedAt: r.updatedAt, onRetry: () => context.read<AccountsCubit>().load()),
            ],
            const SizedBox(height: KSpace.sm),
            if (snap == null)
              const Skeleton(height: 64, radius: KRadius.card)
            else
              for (final a in snap.items) ...[
                AccountTile(account: a, hidden: !_visible),
                const SizedBox(height: KSpace.sm),
              ],
          ],
        );
      },
    );
  }
}

class AccountTile extends StatelessWidget {
  const AccountTile({super.key, required this.account, this.hidden = false, this.category});
  final Account account;
  final bool hidden;
  final String? category;
  @override
  Widget build(BuildContext context) => KCard(
    onTap:
        () => context.push(
          Uri(
            path: '/accounts/${account.id}',
            queryParameters: category == null ? null : {'category': category},
          ).toString(),
        ),
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            account.type == 'checking' ? Icons.account_balance_rounded : Icons.savings_outlined,
            color: KBrand.of(context).action,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(account.alias, style: Theme.of(context).textTheme.titleSmall),
              AccountNumberText(account: account, hidden: hidden),
            ],
          ),
        ),
        AmountText(account.balanceCents, hidden: hidden),
        const Icon(Icons.chevron_right_rounded),
      ],
    ),
  );
}

class MovementTile extends StatelessWidget {
  const MovementTile({super.key, required this.movement});
  final Movement movement;
  @override
  Widget build(BuildContext context) {
    final (label, icon) = categoryOf(movement.category);
    return MergeSemantics(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: KSpace.md),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Icon(icon, size: 20),
        ),
        title: Text(movement.description, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('$label · ${Dates.short(movement.createdAt)}'),
        trailing: AmountText(
          movement.amountCents,
          signed: true,
          colored: movement.amountCents > 0,
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ),
    );
  }
}

class AccountNumberText extends StatelessWidget {
  const AccountNumberText({super.key, required this.account, this.hidden = false, this.style});
  final Account account;
  final bool hidden;
  final TextStyle? style;

  static String group(String number) => number.replaceAllMapped(RegExp(r'.{1,4}'), (m) => '${m[0]} ').trim();

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: account.number));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Número de cuenta copiado'), duration: Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    final text = '${account.typeLabel} · ${hidden ? account.maskedNumber : group(account.number)}';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Semantics(
            // Dígito por dígito para lectores de pantalla.
            label:
                hidden
                    ? '${account.typeLabel}, número de cuenta oculto'
                    : '${account.typeLabel}, número de cuenta ${account.number.split('').join(' ')}',
            excludeSemantics: true,
            child: Text(
              text,
              key: ValueKey('account_number_${account.id}'),
              overflow: TextOverflow.ellipsis,
              style: (style ?? Theme.of(context).textTheme.bodySmall)?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        if (!hidden)
          IconButton(
            key: ValueKey('copy_account_${account.id}'),
            tooltip: 'Copiar número de cuenta',
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            icon: const Icon(Icons.copy_rounded),
            onPressed: () => _copy(context),
          ),
      ],
    );
  }
}

String moneyLabel(int cents) => Money.format(cents);
