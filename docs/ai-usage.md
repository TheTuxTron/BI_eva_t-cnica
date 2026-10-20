# Uso de herramientas de IA en el desarrollo

Este documento describe qué aportaron las herramientas de IA, qué hice yo y qué impacto tuvieron en productividad, calidad, documentación y pruebas.

## Herramientas

| Herramienta | Uso |
|---|---|
| Claude (Anthropic), en modo conversacional con ejecución de código | Análisis del enunciado, propuesta de arquitectura, generación del BFF, de la app Flutter, de las pruebas y de la documentación; apoyo en el diagnóstico de errores |
| GitHub Copilot en VS Code | Autocompletado y ajustes puntuales de código durante la compilación, las correcciones y los cambios posteriores |

## Cómo trabajé con la IA

1. **Del enunciado a un plan verificable.** Partí del PDF completo y armé una matriz de trazabilidad requisito → implementación → evidencia, que está en el README. Así ningún punto del alcance quedó sin cubrir.
2. **Decisiones primero, código después.** Antes de escribir código definí las decisiones clave (BFF, Server-Driven UI, micro-apps con token de alcance mínimo, caché stale-while-revalidate, idempotencia) con sus alternativas. Validé cada una contra mi experiencia desarrollando sobre un core financiero, con Node.js/Express y Flutter.
3. **Generación por capas con verificación inmediata.** El BFF se generó y se ejecutó con sus pruebas antes de seguir. La app se construyó por capas: núcleo, design system, SDUI, features, ensamblaje y pruebas.
4. **Integración, compilación y pruebas en dispositivo.** Compilé, ejecuté en emulador, diagnostiqué y corregí cada falla y probé los escenarios degradados.

## Impacto

| Dimensión | Impacto | Evidencia |
|---|---|---|
| Productividad | Permitió entregar en el plazo de la prueba una solución completa de punta a punta (app, BFF, micro-app, CI y documentación), un alcance que sin asistencia habría obligado a recortar funcionalidades. El tiempo se concentró en decidir, integrar y verificar, no en escribir código repetitivo | Historial de commits |
| Calidad | Pruebas centradas en propiedades críticas y no solo en el caso feliz: que un reintento nunca duplique un débito, la detección de reúso de refresh tokens, el aislamiento entre el token de la micro-app y el de la app, y que la caída de un dominio no afecte a los demás | `bff/test`, `app/test` |
| Documentación | Arquitectura con diagramas C4 y de secuencia, 10 ADRs con el formato pedido (problema, alternativas, decisión, trade-offs, impacto), operación, resiliencia, contrato de micro-apps y design system | `docs/` |
| Pruebas | 29 pruebas del BFF, 51 unitarias y de widgets en la app y 2 flujos E2E contra el BFF real | `npm test`, `flutter test`, `flutter test integration_test` |

## Errores de la IA que detecté y corregí

La IA no tenía acceso a un SDK de Flutter, así que el código Dart se escribió sin compilar. Varios problemas solo aparecieron al compilar y ejecutar en dispositivo; por eso la revisión humana no es opcional.

| Síntoma | Causa | Corrección |
|---|---|---|
| `flutter analyze`: switch no exhaustivo en `failures.dart` | Dio reciente agregó `DioExceptionType.transformTimeout` | Rama `default` que cubre tipos futuros |
| Avisos `use_build_context_synchronously` y `unawaited_futures` | Uso de `context` tras un `await` y Futures de la WebView sin esperar | Verificación `mounted` y `await` de la configuración de la WebView |
| Build Android falla en `:sentry_flutter:compileDebugKotlin` | El plugin compila con Kotlin 1.6 y el toolchain exige 2.0 o superior | Se retiró Sentry y se mantuvo la fachada `Telemetry` (ADR-009) |
| Build Android falla con el mensaje "25.0.3" | Gradle 8.14 ejecutándose con Java 25 | JDK 21 configurado con `flutter config --jdk-dir`; requisito documentado en el README |
| Simulador con error de conexión en el emulador | El BFF devolvía `http://localhost:8080/...`; dentro del emulador `localhost` es el propio dispositivo | El BFF deduce la URL del `Host` de la petición, con salvaguarda en la app y prueba de regresión |
| WebView sin conexión aunque el resto de la app funcionaba | Android bloquea HTTP en claro en la WebView; el cliente HTTP de Dart no aplica esa política | `usesCleartextTraffic` solo en el manifiesto de debug y detalle del error de carga |
| Usuarios creados desaparecían al reiniciar el BFF | Base en memoria y reinicio automático de `npm run dev` | SQLite en archivo; un token de usuario inexistente responde 401 en lugar de 500 |
| Pantalla roja breve al cerrar sesión | Los providers de la sesión se destruían antes de terminar la animación de salida | Liberación diferida de 800 ms; push y polling se detienen al instante |
| Eventos enviados después del logout (401) | Eventos pendientes en memoria | Se descartan al cerrar sesión |
| Prueba del refresh de sesión fallaba | El interceptor modificaba la petición original | `copyWith` en lugar de mutar el objeto |
| E2E no encontraba el campo de monto | `ListView` no construye los campos fuera de pantalla con el teclado abierto | `SingleChildScrollView` en el formulario de transferencia |
| CI: job de commits con exit code 126 | Los scripts `.sh` perdieron el permiso de ejecución al hacer commit desde Windows | `git update-index --chmod=+x` y `bash` explícito en el workflow |
| E2E en CI colgado más de una hora | El emulador sin GPU de GitHub Actions no renderiza (`ColorBuffer`) | Workflow manual con renderizado por software y timeout de 45 min; validación local |

## IA dentro del producto

- **Asistente financiero:** con `ANTHROPIC_API_KEY` responde con un LLM a partir de datos agregados, sin número de cuenta, cédula ni nombres de comercios. Sin clave, o ante una falla, usa un motor de intenciones determinístico, así la función nunca queda caída. La interfaz indica cuándo la respuesta fue generada con IA.
- **Insights:** se calculan de forma determinística a partir de los movimientos reales (30 días contra los 30 anteriores) y no con IA, para que sean auditables.