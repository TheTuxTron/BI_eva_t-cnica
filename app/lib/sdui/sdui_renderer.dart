import 'package:flutter/material.dart';

import '../core/observability/telemetry.dart';
import 'sdui_models.dart';
import 'sdui_registry.dart';

/// Renderiza una lista de secciones. Componentes desconocidos (de una versión más
/// nueva del servidor) se omiten y se reportan; un componente que falla se aísla.
class SduiRenderer extends StatelessWidget {
  const SduiRenderer({
    super.key,
    required this.sections,
    required this.registry,
    required this.telemetry,
    this.spacing = 16,
  });
  final List<SduiSection> sections;
  final SduiRegistry registry;
  final Telemetry telemetry;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (final s in sections) {
      final builder = registry.builderFor(s.type);
      if (builder == null) {
        telemetry.event('sdui_unknown_component', {'type': s.type, 'id': s.id});
        continue;
      }
      Widget child;
      try {
        child = builder(context, s);
      } catch (e, st) {
        telemetry.recordError(e, st, context: {'sdui_type': s.type, 'sdui_id': s.id});
        continue;
      }
      if (children.isNotEmpty) children.add(SizedBox(height: spacing));
      children.add(KeyedSubtree(key: ValueKey('sdui-${s.id}'), child: child));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}
