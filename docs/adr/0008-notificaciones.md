# ADR-008 · Push híbrido: FCM + bandeja persistente

**Problema.** El cliente debe enterarse al instante de sus movimientos. Las push pueden fallar (permiso denegado, token inválido, dispositivos sin Google Play Services) y nunca deben perderse.

**Alternativas evaluadas.**
1. Solo FCM/APNs.
2. WebSockets/SSE persistentes.
3. **FCM para entrega + bandeja persistida en el BFF como fuente de verdad + polling liviano en primer plano como respaldo.**

**Decisión.** Opción 3. `push.notify()` siempre persiste en `notifications` y, si hay credenciales, envía por FCM con `deeplink` en `data`. Los tokens inválidos se limpian solos. La app usa `HybridPushService`: con FCM, el polling es solo una red de seguridad (cada 2 min); sin FCM, el polling es cada 30 s y se pausa en segundo plano.

**Trade-offs.**
- (+) Ninguna notificación se pierde, la demo funciona sin proyecto Firebase y el canal es intercambiable.
- (−) El polling consume algo de batería y red; está acotado a primer plano.
- (−) Los WebSockets dan menor latencia, pero exigen conexiones persistentes, escalado y reconexión en móvil.

**Impacto a largo plazo.** Preferencias por tipo de notificación, campañas segmentadas (ya existe `POST /v1/admin/notifications`) y migración a un servicio de mensajería dedicado sin cambiar la app.
