# API del BFF (v1)

Las rutas autenticadas usan `Authorization: Bearer <access>`. Todas las respuestas incluyen `X-Request-Id`. Los errores tienen el formato `{ "error": { "code", "message", "details?", "requestId" } }`.

| Método | Ruta | Descripción |
|---|---|---|
| POST | `/v1/auth/register` | Onboarding: cédula, datos, contraseña, términos → `userId` + OTP |
| POST | `/v1/auth/otp/verify` · `/otp/resend` | Activa la cuenta, abre la cuenta de ahorros con bono → tokens |
| POST | `/v1/auth/login` · `/refresh` · `/logout` | Sesión con refresh rotativo |
| GET | `/v1/config` | Feature flags, versión mínima, esquema SDUI |
| GET / PUT | `/v1/me` · `/v1/me/preferences` | Perfil, segmento y preferencias |
| POST | `/v1/me/events` | Eventos de comportamiento (lotes) |
| GET | `/v1/accounts` · `/v1/accounts/:id` | Cuentas y saldo consolidado |
| GET | `/v1/accounts/:id/movements?cursor&limit&category` | Movimientos paginados por cursor |
| GET | `/v1/accounts/lookup?number=` | Verificación del destinatario (titular enmascarado) |
| POST | `/v1/transfers` | Transferencia. **Requiere `Idempotency-Key`** |
| GET | `/v1/experience/home` | Experiencia SDUI personalizada |
| GET | `/v1/insights` | Análisis de gastos calculado de movimientos reales |
| POST | `/v1/assistant/messages` | Asistente (LLM opcional + reglas) |
| GET | `/v1/fx/rates` | Tipo de cambio (Frankfurter/BCE) con circuit breaker |
| GET / POST | `/v1/notifications` · `/:id/read` · `/read-all` | Bandeja |
| POST / DELETE | `/v1/devices` | Registro del token FCM |
| GET / POST | `/v1/microapps` · `/:id/session` | Catálogo y sesión de micro-apps |
| POST | `/v1/microapp-api/simulador-credito/simulate` | API de la micro-app (token de micro-app) |
| GET / PUT / DELETE | `/v1/admin/chaos` | Fault injection (header `X-Admin-Key`) |
| GET / PUT | `/v1/admin/flags` | Feature flags |
| GET / POST / PATCH | `/v1/admin/campaigns` | Campañas SDUI |
| POST | `/v1/admin/notifications` | Push de prueba a un usuario |
| GET | `/health/live` · `/health/ready` · `/metrics` | Salud y métricas |
