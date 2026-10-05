import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../sdui/sdui_registry.dart';

/// Contrato que cada dominio funcional implementa. Permite que equipos independientes
/// aporten dependencias, rutas y componentes SDUI sin modificar el núcleo de la app.
/// Evolución prevista: cada módulo → su propio package (ver ADR-002).
abstract class FeatureModule {
  String get name;

  /// Registra repositorios/servicios del dominio en el contenedor.
  void registerDependencies(GetIt sl) {}

  /// Rutas a pantalla completa (fuera de la barra de navegación).
  List<RouteBase> get routes => const [];

  /// Componentes que este dominio aporta al catálogo SDUI.
  void registerComponents(SduiRegistry registry) {}
}
