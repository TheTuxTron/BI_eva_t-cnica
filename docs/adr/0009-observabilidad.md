# ADR-009 · Fachada de telemetría + Prometheus + correlación (proveedor de crashes enchufable)

**Problema.** En producción hay que detectar problemas operativos (errores, latencia, dependencias caídas) y de experiencia (embudos que se rompen, pantallas lentas, fallbacks) y poder diagnosticar un caso puntual de punta a punta.

**Alternativas evaluadas.** Usar el SDK de un proveedor directamente en cada feature, o **una fachada `Telemetry` con varios destinos**.

**Decisión.**
- **App:** interfaz `Telemetry` con `CompositeTelemetry` y tres destinos:
  - `ConsoleTelemetry`: logs JSON por línea.
  - Destino de crashes (Sentry o Crashlytics): ver *Actualización* al final.
  - `BehaviorEventsTelemetry`: eventos de comportamiento al BFF, que alimentan la personalización.

  Errores globales capturados vía `FlutterError.onError` y `PlatformDispatcher.onError`.
- **Correlación:** cada request lleva `X-Request-Id`; el mismo ID aparece en la telemetría de la app, en los logs del BFF (pino) y en la UI de error ("Código de soporte").
- **BFF:** `/metrics` (Prometheus) con latencia por ruta, logins, transferencias, llamadas a terceros y eventos de UX, más `/health/live` y `/health/ready` (incluye el estado del circuit breaker).

**Trade-offs.**
- (+) Las features no conocen al proveedor, se puede cambiar o duplicar destinos y los datos sensibles se controlan en un solo lugar (sin PII por defecto, redacción de headers).
- (−) La fachada requiere mantener la paridad de funciones con los SDK.

**Impacto a largo plazo.** Migración a OpenTelemetry (trazas distribuidas app → BFF → core) reutilizando el `X-Request-Id` como `traceparent`. Ver `docs/deployment-operations.md` para SLOs, dashboards y alertas.

## Actualización (integración)

La primera versión incluía `sentry_flutter` 8.x. Al compilar con Flutter y Gradle actuales, el build falló: ese plugin compila con Kotlin *language version* 1.6 y el toolchain ya exige 2.0 o superior. Se retiró la dependencia y se mantuvo la fachada. Este es justamente el beneficio de la decisión: **ninguna feature cambió**. Para reactivarlo basta con implementar `SentryTelemetry implements Telemetry` cuando exista una versión del plugin compatible con *Built-in Kotlin*, o usar Firebase Crashlytics si se configura Firebase para push.
