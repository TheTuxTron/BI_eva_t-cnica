# ADR-009 · Fachada de telemetría, métricas Prometheus y correlación de punta a punta

**Problema.** En producción hay que detectar problemas operativos (errores, latencia, dependencias caídas) y de experiencia (embudos que se rompen, pantallas lentas, fallbacks), y poder diagnosticar un caso puntual de punta a punta.

**Alternativas evaluadas.** Usar el SDK de un proveedor directamente en cada feature, o una fachada `Telemetry` con varios destinos intercambiables.

**Decisión.**
- **App:** interfaz `Telemetry` implementada por `CompositeTelemetry`, que reparte cada evento entre sus destinos:
  - `ConsoleTelemetry`: logs JSON por línea, visibles en `flutter run` y `adb logcat`.
  - `BehaviorEventsTelemetry`: eventos de comportamiento enviados en lotes al BFF; alimentan la personalización y las métricas de UX.
  - Destino de crashes (Sentry o Firebase Crashlytics): se conecta implementando `Telemetry`, sin tocar las features.

  Los errores no controlados se capturan con `FlutterError.onError` y `PlatformDispatcher.onError`.
- **Correlación:** cada petición lleva un `X-Request-Id`. El mismo ID aparece en la telemetría de la app, en los logs del BFF (pino) y en la pantalla de error como "Código de soporte".
- **BFF:** `/metrics` (Prometheus) con latencia por ruta, logins, transferencias, llamadas a terceros y eventos de UX, además de `/health/live` y `/health/ready`, que incluye el estado del circuit breaker.

**Trade-offs.**
- (+) Las features no dependen del proveedor; se pueden cambiar o combinar destinos y los datos sensibles se controlan en un solo lugar (sin PII por defecto, redacción de headers en los logs).
- (−) La fachada debe mantener la paridad de funciones con los SDK que envuelve.

**Validación de la decisión durante la integración.** La primera versión incluía `sentry_flutter` 8.x. Al compilar con el toolchain actual, el build falló: ese plugin usa Kotlin 1.6 y Gradle ya exige Kotlin 2.0 o superior. Se retiró la dependencia y ninguna feature tuvo que cambiar, que es justamente el beneficio buscado. Se reconectará cuando exista una versión compatible, o con Crashlytics al configurar Firebase.

**Impacto a largo plazo.** Migración a OpenTelemetry (trazas distribuidas app → BFF → core) reutilizando el `X-Request-Id` como `traceparent`. SLOs, alertas y runbooks en `docs/deployment-operations.md`.
