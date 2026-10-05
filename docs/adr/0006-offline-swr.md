# ADR-006 · Stale-while-revalidate con caché local por usuario

**Problema.** En redes móviles con mala señal, alta latencia o caídas parciales, el cliente debe poder ver su información y entender qué tan actualizada está, en lugar de encontrarse con pantallas de error.

**Alternativas evaluadas.**
1. Sin caché (siempre red).
2. Offline-first con base local sincronizada (drift/Isar + sincronización).
3. **Stale-while-revalidate (SWR): mostrar la última copia conocida al instante y revalidar en segundo plano.**

**Decisión.** SWR genérico (`staleWhileRevalidate<T>`) para cuentas, primera página de movimientos, experiencia de inicio, tipo de cambio y bandeja. La caché está namespaced por usuario y se borra al cerrar sesión. Las operaciones que mueven dinero nunca se encolan offline: requieren confirmación del servidor.

**Trade-offs.**
- (+) El tiempo a primer contenido es inmediato, la app funciona en modo lectura sin red y la UI marca "datos de hace X min".
- (−) El saldo mostrado puede no ser el actual. Se comunica explícitamente y la validación final de fondos ocurre en el servidor.
- (−) La opción 2 permitiría búsqueda offline completa, pero agrega complejidad de sincronización y conflictos que no aporta valor para un MVP.

**Impacto a largo plazo.** El riesgo R-04 (caché en `SharedPreferences` sin cifrar) se mitiga en producción con almacenamiento cifrado (clave en Keystore/Keychain) sin cambiar la API de `CacheStore`.
