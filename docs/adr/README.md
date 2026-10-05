# Registro de decisiones de arquitectura (ADR)

Cada ADR documenta: problema, alternativas evaluadas, opción seleccionada, trade-offs e impacto a largo plazo.

| # | Decisión | Estado |
|---|----------|--------|
| [001](0001-bff.md) | Backend for Frontend propio entre la app y los servicios | Aceptada |
| [002](0002-modularizacion.md) | Módulos por dominio con contrato `FeatureModule` | Aceptada |
| [003](0003-gestion-estado.md) | BLoC/Cubit para gestión de estado | Aceptada |
| [004](0004-server-driven-ui.md) | Server-Driven UI para experiencias sin publicar la app | Aceptada |
| [005](0005-micro-apps.md) | Micro-apps externas vía WebView + bridge con token de alcance mínimo | Aceptada |
| [006](0006-offline-swr.md) | Stale-while-revalidate con caché local por usuario | Aceptada |
| [007](0007-resiliencia-red.md) | Reintentos selectivos, idempotencia y circuit breaker | Aceptada |
| [008](0008-notificaciones.md) | Push híbrido: FCM + bandeja persistente | Aceptada |
| [009](0009-observabilidad.md) | Fachada de telemetría + Sentry + Prometheus + correlación | Aceptada |
| [010](0010-trunk-based.md) | Trunk Based Development con feature flags | Aceptada |
