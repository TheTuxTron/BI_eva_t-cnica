import 'package:flutter/widgets.dart';

import 'sdui_models.dart';

typedef SduiBuilder = Widget Function(BuildContext context, SduiSection section);

/// Catálogo de componentes. Cada feature (equipo) registra los suyos desde su módulo,
/// sin que el motor conozca a las features: así se agregan componentes sin acoplamiento.
class SduiRegistry {
  final Map<String, SduiBuilder> _builders = {};

  void register(String type, SduiBuilder builder) {
    assert(!_builders.containsKey(type), 'Componente SDUI duplicado: $type');
    _builders[type] = builder;
  }

  SduiBuilder? builderFor(String type) => _builders[type];
  bool supports(String type) => _builders.containsKey(type);
  Iterable<String> get types => _builders.keys;
}
