# ADR-009 · Fachada de telemetría + Sentry + Prometheus + correlación

**Problema.** En producción hay que detectar problemas operativos (errores, latencia, dependencias caídas) y de experiencia (embudos que se rompen, pantallas lentas, fallbacks) y poder diagnosticar un caso puntual de punta a punta.

**Alternativas evaluadas.** Usar el SDK de un proveedor directamente en cada feature, o **una fachada `Telemetry` con varios destinos**.

**Decisión.**
- **App:** interfaz `Telemetry` con `CompositeTelemetry` y tres destinos:
  - `ConsoleTelemetry`: logs JSON por línea.
  - `SentryTelemetry`: crashes, errores con contexto, breadcrumbs y performance.
  - `BehaviorEventsTelemetry`: eventos de comportamiento al BFF, que alimentan la personalización.

  Errores globales capturados vía `FlutterError.onError` y `PlatformDispatcher.onError`.
- **Correlación:** cada request lleva `X-Request-Id`; el mismo ID aparece en Sentry, en los logs del BFF (pino) y en la UI de error ("Código de soporte").
- **BFF:** `/metrics` (Prometheus) con latencia por ruta, logins, transferencias, llamadas a terceros y eventos de UX, más `/health/live` y `/health/ready` (incluye el estado del circuit breaker).

**Trade-offs.**
- (+) Las features no conocen al proveedor, se puede cambiar o duplicar destinos y los datos sensibles se controlan en un solo lugar (`sendDefaultPii=false`, redacción de headers).
- (−) La fachada requiere mantener la paridad de funciones con los SDK.

**Impacto a largo plazo.** Migración a OpenTelemetry (trazas distribuidas app → BFF → core) reutilizando el `X-Request-Id` como `traceparent`. Ver `docs/deployment-operations.md` para SLOs, dashboards y alertas.
