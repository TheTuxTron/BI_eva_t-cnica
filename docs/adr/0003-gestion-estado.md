# ADR-003 · BLoC/Cubit para gestión de estado

**Problema.** Se necesita un manejo de estado predecible, testeable y explícito en escenarios degradados (cargando, datos de caché, error con datos, incierto), que varios equipos puedan seguir de forma consistente.

**Alternativas evaluadas.** Provider/ChangeNotifier, Riverpod, GetX, MobX y **flutter_bloc (Cubit)**.

**Decisión.** Cubit (flutter_bloc) + Equatable, con estados inmutables. Para datos remotos, un tipo genérico `Resource<T>` modela de forma uniforme: dato, error, refrescando, desde caché y fecha de actualización.

**Trade-offs.**
- (+) Estándar de facto en banca y fintech: fácil de auditar, muy testeable (`bloc_test`) y con transiciones explícitas. Separa UI de lógica.
- (−) Más boilerplate que Riverpod. La inyección se hace con `get_it`, de forma explícita y fuera del árbol de widgets.
- (−) GetX es rápido de escribir pero mezcla navegación, DI y estado, y es difícil de testear y gobernar entre equipos.

**Impacto a largo plazo.** Las convenciones (`Resource<T>`, `copyWith`, estados con `Equatable`) hacen que un dominio nuevo luzca igual que los existentes y sea predecible para cualquier equipo. Los estados de sesión (cuentas, inicio, notificaciones) viven en `SessionScope` y se destruyen al cerrar sesión, lo que elimina por diseño la fuga de datos entre usuarios.
