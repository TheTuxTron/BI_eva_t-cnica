import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di.dart';
import '../../../core/observability/telemetry.dart';
import '../../../core/utils/formatters.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/widgets.dart';
import '../../accounts/data/accounts_repository.dart';
import '../../accounts/presentation/accounts_cubit.dart';
import '../../notifications/presentation/notifications_cubit.dart';
import '../data/transfers_repository.dart';
import 'transfer_cubit.dart';

class TransferPage extends StatelessWidget {
  const TransferPage({super.key, this.fromAccountId});
  final String? fromAccountId;

  @override
  Widget build(BuildContext context) {
    final accounts = context.read<AccountsCubit>().state.data?.items ?? const <Account>[];
    final initial = fromAccountId ?? (accounts.isNotEmpty ? accounts.first.id : null);
    return BlocProvider(
      create:
          (_) => TransferCubit(
            transfers: sl<TransfersRepository>(),
            accounts: sl<AccountsRepository>(),
            telemetry: sl<Telemetry>(),
            initialFrom: initial,
          ),
      child: BlocConsumer<TransferCubit, TransferState>(
        listenWhen: (a, b) => a.step != b.step && b.step == TransferStep.success,
        listener: (context, _) {
          // Saldos y bandeja se actualizan de inmediato (sin esperar al push/polling).
          context.read<AccountsCubit>().load();
          context.read<NotificationsCubit>().refresh();
        },
        builder:
            (context, s) => PopScope(
              canPop: s.step != TransferStep.processing,
              child: Scaffold(
                appBar: AppBar(title: const Text('Transferir')),
                body: SafeArea(
                  child: AnimatedSwitcher(
                    duration: KMotion.medium,
                    child: switch (s.step) {
                      TransferStep.form => const _FormView(key: ValueKey('form')),
                      TransferStep.confirm || TransferStep.processing => const _ConfirmView(key: ValueKey('confirm')),
                      TransferStep.success => const _SuccessView(key: ValueKey('success')),
                      TransferStep.uncertain => const _UncertainView(key: ValueKey('uncertain')),
                      TransferStep.rejected => const _RejectedView(key: ValueKey('rejected')),
                    },
                  ),
                ),
              ),
            ),
      ),
    );
  }
}

class _FormView extends StatefulWidget {
  const _FormView({super.key});
  @override
  State<_FormView> createState() => _FormViewState();
}

class _FormViewState extends State<_FormView> {
  final _form = GlobalKey<FormState>();
  late final _to = TextEditingController(text: context.read<TransferCubit>().state.toNumber);
  late final _amount = TextEditingController(
    text: () {
      final c = context.read<TransferCubit>().state.amountCents;
      return c > 0 ? Money.toApi(c) : '';
    }(),
  );
  late final _desc = TextEditingController(text: context.read<TransferCubit>().state.description);

  @override
  void dispose() {
    _to.dispose();
    _amount.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<TransferCubit>().state;
    final accountsRes = context.watch<AccountsCubit>().state;
    final accounts = accountsRes.data?.items ?? const <Account>[];
    final from = firstWhereOrNull(accounts, (Account a) => a.id == s.fromAccountId);
    final others = accounts.where((a) => a.id != s.fromAccountId).toList();

    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(KSpace.lg),
        children: [
          Text('Desde', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: KSpace.sm),
          if (accounts.isEmpty)
            const Skeleton(height: 56)
          else
            DropdownButtonFormField<String>(
              key: const Key('transfer_from'),
              initialValue: s.fromAccountId,
              isExpanded: true,
              decoration: kInput(context, label: 'Cuenta origen'),
              items: [
                for (final a in accounts)
                  DropdownMenuItem(
                    value: a.id,
                    child: Text(
                      '${a.alias} ${a.maskedNumber} · ${Money.format(a.balanceCents)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) {
                if (v != null) context.read<TransferCubit>().selectFrom(v);
              },
            ),
          if (accountsRes.isStale)
            const Padding(
              padding: EdgeInsets.only(top: KSpace.sm),
              child: Text('El saldo mostrado puede no estar actualizado.'),
            ),
          const SizedBox(height: KSpace.lg),
          Text('Para', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: KSpace.sm),
          if (others.isNotEmpty)
            Wrap(
              spacing: 8,
              children: [
                for (final o in others)
                  ActionChip(
                    avatar: const Icon(Icons.person_outline, size: 18),
                    label: Text('Mi ${o.alias.toLowerCase()} ${o.maskedNumber}'),
                    onPressed: () {
                      _to.text = o.number;
                      context.read<TransferCubit>().setDestination(o.number);
                    },
                  ),
              ],
            ),
          const SizedBox(height: KSpace.sm),
          TextFormField(
            key: const Key('transfer_to'),
            controller: _to,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
            onChanged: (v) => context.read<TransferCubit>().setDestination(v),
            decoration: kInput(
              context,
              label: 'Número de cuenta Kinti',
              error: s.recipientError,
              prefix: const Icon(Icons.account_balance_outlined),
              suffix:
                  s.lookingUp
                      ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                      : s.recipient != null
                      ? const Icon(Icons.verified_rounded, color: KColors.positive)
                      : null,
              helper: s.recipient != null ? 'Titular: ${s.recipient!.holder}' : null,
            ),
            validator: (_) => s.recipient == null ? 'Verifica la cuenta destino' : null,
          ),
          const SizedBox(height: KSpace.md),
          TextFormField(
            key: const Key('transfer_amount'),
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            decoration: kInput(
              context,
              label: 'Monto (USD)',
              prefix: const Icon(Icons.attach_money),
              helper: from == null ? null : 'Disponible: ${Money.format(from.balanceCents)}',
            ),
            validator: (v) {
              final c = Money.parseToCents(v ?? '');
              if (c == null || c <= 0) return 'Ingresa un monto válido';
              if (from != null && c > from.balanceCents) return 'Saldo insuficiente';
              return null;
            },
          ),
          const SizedBox(height: KSpace.md),
          TextFormField(
            key: const Key('transfer_desc'),
            controller: _desc,
            maxLength: 40,
            decoration: kInput(context, label: 'Descripción (opcional)'),
          ),
          if (s.failure != null) Text(s.failure!.message, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: KSpace.md),
          FilledButton(
            key: const Key('transfer_continue'),
            onPressed: () {
              if (!(_form.currentState?.validate() ?? false)) return;
              context.read<TransferCubit>().review(
                amountCents: Money.parseToCents(_amount.text)!,
                description: _desc.text,
                availableCents: from?.balanceCents ?? 0,
              );
            },
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }
}

class _ConfirmView extends StatelessWidget {
  const _ConfirmView({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<TransferCubit>().state;
    final processing = s.step == TransferStep.processing;
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(KSpace.lg),
      children: [
        Text('Confirma tu transferencia', style: t.titleLarge),
        const SizedBox(height: KSpace.lg),
        Center(child: AmountText(s.amountCents, style: t.displaySmall?.copyWith(fontWeight: FontWeight.w800))),
        const SizedBox(height: KSpace.lg),
        KCard(
          child: Column(
            children: [
              _row(
                context,
                'Para',
                '${s.recipient?.holder ?? ''} · ****${s.toNumber.substring(s.toNumber.length - 4)}',
              ),
              const Divider(),
              _row(context, 'Descripción', s.description.isEmpty ? 'Transferencia' : s.description),
              const Divider(),
              _row(context, 'Costo', 'Sin costo'),
            ],
          ),
        ),
        const SizedBox(height: KSpace.xl),
        LoadingButton(
          key: const Key('transfer_confirm'),
          label: 'Confirmar y enviar',
          loading: processing,
          onPressed: () => context.read<TransferCubit>().confirm(),
        ),
        const SizedBox(height: KSpace.sm),
        OutlinedButton(
          onPressed: processing ? null : () => context.read<TransferCubit>().edit(),
          child: const Text('Editar'),
        ),
        if (processing)
          const Padding(
            padding: EdgeInsets.only(top: KSpace.md),
            child: Text(
              'Procesando de forma segura. Si la conexión es lenta reintentaremos sin duplicar el cobro.',
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  Widget _row(BuildContext context, String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(child: Text(k, style: Theme.of(context).textTheme.bodyMedium)),
        Flexible(child: Text(v, textAlign: TextAlign.end, style: Theme.of(context).textTheme.titleSmall)),
      ],
    ),
  );
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({super.key});
  @override
  Widget build(BuildContext context) {
    final r = context.watch<TransferCubit>().state.receipt!;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(KSpace.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.check_circle_rounded, size: 72, color: KColors.positive),
          const SizedBox(height: KSpace.md),
          Semantics(
            liveRegion: true,
            child: Text(
              '¡Transferencia enviada!',
              key: const Key('transfer_success'),
              textAlign: TextAlign.center,
              style: t.headlineSmall,
            ),
          ),
          const SizedBox(height: KSpace.sm),
          Text(
            '${Money.format(r.amountCents)} a la cuenta ${r.toMaskedNumber}',
            textAlign: TextAlign.center,
            style: t.bodyLarge,
          ),
          const SizedBox(height: KSpace.xs),
          SelectableText('Comprobante ${r.id}', textAlign: TextAlign.center, style: t.bodySmall),
          const SizedBox(height: KSpace.xl),
          FilledButton(
            key: const Key('transfer_done'),
            onPressed: () => context.go('/home'),
            child: const Text('Volver al inicio'),
          ),
        ],
      ),
    );
  }
}

class _UncertainView extends StatelessWidget {
  const _UncertainView({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<TransferCubit>().state;
    return Padding(
      padding: const EdgeInsets.all(KSpace.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.sync_problem_rounded, size: 64, color: KColors.warning),
          const SizedBox(height: KSpace.md),
          Text(
            'No pudimos confirmar tu transferencia',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: KSpace.sm),
          Text(
            '${s.failure?.message ?? ''}\nReintentar es seguro: si ya se procesó, no se cobrará dos veces.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: KSpace.xl),
          FilledButton.icon(
            key: const Key('transfer_retry'),
            onPressed: () => context.read<TransferCubit>().confirm(),
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
          const SizedBox(height: KSpace.sm),
          OutlinedButton(onPressed: () => context.go('/home'), child: const Text('Revisar más tarde')),
        ],
      ),
    );
  }
}

class _RejectedView extends StatelessWidget {
  const _RejectedView({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<TransferCubit>().state;
    return Padding(
      padding: const EdgeInsets.all(KSpace.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.block_rounded, size: 64, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: KSpace.md),
          Text(
            s.failure?.message ?? 'No se pudo completar',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: KSpace.xl),
          FilledButton(onPressed: () => context.read<TransferCubit>().edit(), child: const Text('Corregir datos')),
        ],
      ),
    );
  }
}
