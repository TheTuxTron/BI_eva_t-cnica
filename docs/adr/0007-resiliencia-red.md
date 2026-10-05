# ADR-007 · Reintentos selectivos, idempotencia y circuit breaker

**Problema.** Ante timeouts o errores 5xx, reintentar mejora la tasa de éxito. Pero reintentar una transferencia sin protección puede debitar dos veces, que es el peor fallo posible en banca.

**Alternativas evaluadas.**
1. Sin reintentos (el usuario reintenta manualmente).
2. Reintentar todo.
3. **Reintentar solo lo seguro: métodos idempotentes o POST con `Idempotency-Key`, con backoff exponencial + jitter.**

**Decisión.**
- **App:** `RetryInterceptor` reintenta como máximo 3 veces con backoff (400 ms × 2ⁿ + jitter, tope 5 s, respeta `Retry-After`), solo ante fallas de conexión, timeouts, 502, 503, 504 o 429. `TransferCubit` genera una clave por intención de pago, la conserva en reintentos y la descarta si cambian los datos. Si tras los reintentos el resultado es incierto, muestra un estado "No pudimos confirmar" con un reintento seguro.
- **BFF:** tabla `idempotency (key, user_id, request_hash)`. El mismo key con el mismo body devuelve la respuesta original (`Idempotent-Replayed: true`). El mismo key con otro body responde 409.
- **Terceros:** un circuit breaker (3 fallas → abierto 30 s → half-open) protege al tipo de cambio y sirve la caché vencida marcada como `stale`.

**Trade-offs.**
- (+) No hay doble débito por diseño y el sistema se recupera solo ante fallas transitorias.
- (−) Más latencia percibida en el peor caso (hasta ~10 s). Se comunica en la UI y el estado incierto es honesto con el usuario.
- (−) La tabla de idempotencia crece y en producción requiere TTL (24–72 h).

**Impacto a largo plazo.** El patrón se extiende a cualquier operación con efecto (pagos, recargas). Para varias instancias del BFF, la tabla de idempotencia pasa a un almacén compartido (Redis/DB) con lock por clave.
