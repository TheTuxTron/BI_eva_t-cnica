# Comportamiento ante conectividad limitada, alta latencia e indisponibilidad parcial

## 1. Principios

1. **Mostrar algo útil siempre:** caché primero, red después (SWR). La pantalla de error solo aparece si no hay ningún dato.
2. **Ser honesto con el usuario:** se indica cuándo los datos son guardados ("hace 5 min"), cuándo la red está inestable y cuándo un resultado es incierto.
3. **Reintentar solo lo seguro:** lecturas y operaciones con `Idempotency-Key`. Nunca se duplica un débito.
4. **Aislar fallas:** la caída de un dominio o tercero degrada solo su módulo.
5. **Recuperarse sin pedir nada:** al volver la conexión, la app revalida sola.

## 2. Mecanismos implementados

| Mecanismo | Dónde | Detalle |
|---|---|---|
| Timeouts | `app/di.dart` | connect 8 s · send 10 s · receive 15 s |
| Reintentos con backoff + jitter | `RetryInterceptor` | Máx. 3, 400 ms × 2ⁿ + jitter, tope 5 s, respeta `Retry-After`. Solo conexión, timeouts, 502/503/504/429 y métodos seguros |
| Idempotencia | `TransferCubit` + BFF | Una clave por intención; replay devuelve la misma respuesta |
| Refresh de sesión serializado | `AuthInterceptor` (QueuedInterceptor) | N requests con token vencido → 1 refresh |
| Caché SWR por usuario | `staleWhileRevalidate` | Cuentas, movimientos (página 1), inicio, FX, bandeja |
| Fallback de experiencia | `HomeExperienceCubit` | Fresco → caché → experiencia embebida |
| Detección de calidad de red | `NetworkHealth` + `ConnectivityCubit` | Estado del enlace + fallas reales consecutivas |
| Banner de conectividad | `ConnectivityBanner` | Sin conexión · inestable · restablecida |
| Recuperación automática | `SessionScope` | Al recuperar la conexión se recargan cuentas, inicio, FX y bandeja |
| Circuit breaker a terceros | BFF `fx.js` | 3 fallas → abierto 30 s → half-open; sirve caché `stale` |
| Paginación tolerante | `MovementsCubit` | Si falla "cargar más" se conservan los datos y se ofrece reintentar |
| Estado incierto | Transferencias | "No pudimos confirmar" + reintento seguro con la misma clave |
| Timeout de micro-app | `MicroappPage` | Si no llega `ready` en 12 s → error con reintento |

## 3. Matriz de escenarios (cómo demostrarlo)

Los escenarios se activan desde la app (**Perfil → Diagnóstico y resiliencia**) o con `make chaos-*`. El modo avión del dispositivo sirve para el escenario "sin conexión".

| Escenario | Cómo activarlo | Comportamiento esperado |
|---|---|---|
| Sin conexión | Modo avión | Banner oscuro "Sin conexión"; saldos, movimientos e inicio desde caché con "datos de hace X"; transferir muestra error claro; al volver la red: banner verde y recarga automática |
| Alta latencia | Preset "Latencia alta" (3 s ± 1 s) | Skeletons y caché visibles; los botones muestran progreso; tras fallas consecutivas, banner "Conexión inestable" |
| Errores intermitentes | Preset "Errores intermitentes" (40 % de 503 en cuentas y transferencias) | Los reintentos con backoff ocultan la mayoría de fallas; la transferencia termina con un solo débito o pasa a estado incierto con reintento seguro |
| Cae personalización | Preset "Cae personalización" | El inicio sigue con la última versión; tras "Borrar caché", aparece la experiencia simplificada embebida |
| Cae tercero (FX) | Preset "Cae tipo de cambio" | Solo la tarjeta de FX muestra "Último dato disponible" o "no disponible"; el resto del inicio intacto |
| Caen cuentas | Preset "Caen cuentas" | Saldos desde caché con aviso; las transferencias informan indisponibilidad (`Retry-After`) |
| Sesión vencida | Esperar 15 min o revocar | Refresh transparente; si el refresh es inválido → login con aviso "Tu sesión terminó por seguridad" |
| Recuperación | Preset "Normal" | Banner "Conexión restablecida" y datos frescos sin acción del usuario |
