import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/di.dart';
import '../../../core/cache/resource.dart';
import '../../../core/observability/telemetry.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/widgets.dart';
import '../../../sdui/sdui_models.dart';
import '../data/fx_repository.dart';

class FxCubit extends Cubit<Resource<FxRates>> {
  FxCubit(this._repo) : super(const Resource.loading());
  final FxRepository _repo;
  StreamSubscription<Resource<FxRates>>? _sub;

  Future<void> load() async {
    await _sub?.cancel();
    final done = Completer<void>();
    _sub = _repo.watchRates().listen(emit, onDone: () {
      if (!done.isCompleted) done.complete();
    });
    return done.future;
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}

const _flags = {'EUR': '🇪🇺', 'COP': '🇨🇴', 'PEN': '🇵🇪', 'MXN': '🇲🇽', 'GBP': '🇬🇧', 'CNY': '🇨🇳'};

/// Componente SDUI "fx_rates". Si el proveedor externo cae, el módulo se degrada
/// solo (mensaje discreto) sin afectar al resto del inicio.
class FxRatesComponent extends StatelessWidget {
  const FxRatesComponent({super.key, required this.section});
  final SduiSection section;

  @override
  Widget build(BuildContext context) {
    final symbols = section.data['symbols'] is List ? (section.data['symbols'] as List).map((e) => '$e').toList() : const ['EUR', 'COP'];
    return BlocBuilder<FxCubit, Resource<FxRates>>(
      builder: (context, r) {
        if (r.data == null && r.isRefreshing && r.error == null) return const Skeleton(height: 96, radius: KRadius.card);
        return KCard(
          onTap: () => sl<Telemetry>().event('screen_fx'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(section.str('title') ?? 'Tipo de cambio', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
              if (r.data != null) Text('1 USD · ${r.data!.date}', style: Theme.of(context).textTheme.bodySmall),
            ]),
            const SizedBox(height: KSpace.sm),
            if (r.data == null)
              Row(children: [
                const Icon(Icons.cloud_off_outlined, size: 18),
                const SizedBox(width: 8),
                const Expanded(child: Text('Tipo de cambio no disponible por ahora')),
                TextButton(onPressed: () => context.read<FxCubit>().load(), child: const Text('Reintentar')),
              ])
            else ...[
              Wrap(spacing: KSpace.md, runSpacing: KSpace.sm, children: [
                for (final s in symbols.where(r.data!.rates.containsKey))
                  Semantics(
                    label: '1 dólar equivale a ${r.data!.rates[s]} $s',
                    excludeSemantics: true,
                    child: Text(
                      '${_flags[s] ?? ''} $s ${r.data!.rates[s]!.toStringAsFixed(r.data!.rates[s]! > 100 ? 0 : 4)}',
                      style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
                    ),
                  ),
              ]),
              if (r.isStale || r.data!.serverStale)
                Padding(
                  padding: const EdgeInsets.only(top: KSpace.sm),
                  child: Text('Último dato disponible (proveedor externo sin respuesta)', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: KColors.warning)),
                ),
              Padding(
                padding: const EdgeInsets.only(top: KSpace.xs),
                child: Text('Fuente: Banco Central Europeo vía Frankfurter', style: Theme.of(context).textTheme.labelSmall),
              ),
            ],
          ]),
        );
      },
    );
  }
}
