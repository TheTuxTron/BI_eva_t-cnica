# Uso de herramientas de IA en el desarrollo

> Este documento es parte de los entregables. Describe con honestidad qué hizo la IA, qué hice yo y qué impacto tuvo. Las secciones marcadas **[Completar]** las llené después de compilar y probar en dispositivo.

## Herramientas

| Herramienta | Uso |
|---|---|
| Claude (Anthropic), en modo conversacional con ejecución de código | Análisis del enunciado, propuesta de arquitectura, generación del BFF, de la app Flutter, de las pruebas y de la documentación |
| [Completar: p. ej. GitHub Copilot / Gemini en Android Studio] | Autocompletado y correcciones durante la compilación |

## Cómo trabajé con la IA

1. **Del requerimiento a un plan verificable.** Le di el PDF completo y le pedí cubrir cada punto. Trabajamos sobre una matriz de trazabilidad requisito → implementación → evidencia (ver README).
2. **Decisiones primero, código después.** Antes de generar código se definieron las decisiones clave (BFF, SDUI, micro-apps con token de alcance mínimo, SWR, idempotencia) con sus alternativas. Validé cada una contra mi experiencia en el sector financiero: core bancario, Node.js/Express y Flutter.
3. **Generación por capas con verificación inmediata.** El BFF se generó y **se ejecutó en el entorno de la IA**: 25 pruebas automatizadas pasando antes de seguir. La app Flutter se generó por capas (núcleo, design system, SDUI, features, ensamblaje, pruebas).
4. **Revisión humana, compilación e integración.** Yo compilé, ejecuté en emulador/dispositivo, corregí, probé los escenarios degradados y grabé la demostración. Los commits en `main` reflejan ese proceso de integración.

## Qué hizo bien la IA

- **Productividad:** generó en horas un volumen de código y documentación que a mano me habría tomado días: BFF completo, ~70 archivos Dart, ADRs y diagramas Mermaid.
- **Cobertura del enunciado:** sostuvo una lista de requisitos y escenarios degradados sin olvidar ítems (monitoreo, conectividad, IA, TBD).
- **Pruebas:** propuso casos que demuestran propiedades importantes, no solo "happy paths": que un reintento nunca duplique un débito, la detección de reúso de refresh tokens, el aislamiento entre tokens de micro-app y de la app, y que la caída de un dominio no afecte a otros.
- **Documentación:** los ADRs siguen el formato pedido (problema, alternativas, decisión, trade-offs, impacto).

## Errores de la IA que tuve que detectar o corregir

Estos ocurrieron de verdad durante el desarrollo y son la razón por la que la revisión humana no es opcional:

- **Sin SDK de Flutter:** el entorno de la IA no tenía Flutter, así que el código Dart se escribió sin compilar. La primera compilación y `flutter analyze` los hice yo. [Completar: errores encontrados al compilar y cómo los resolví]
- **Conflicto con `Equatable`:** la IA nombró `props` a un campo de `SduiSection`, que choca con el getter de Equatable. Lo detectó en revisión y lo renombró a `data`.
- **Expresiones `void` en ternarios** (`cond ? null : cubit.metodo()`), que son error de compilación en Dart. Se corrigieron antes de entregar.
- **APIs de tema que cambiaron entre versiones de Flutter** (`CardTheme` → `CardThemeData`, etc.). Se reemplazaron por widgets propios para no depender de la versión.
- **Pruebas del BFF frágiles:** un patrón de `supertest` que creaba requests anidados falló en 6 pruebas y se reescribió.
- **Posible condición de carrera en la micro-app:** el mensaje `ready` podía llegar antes de asignar la sesión. Se corrigió asignando el estado antes de cargar la página.
- [Completar: otros ajustes hechos al probar en dispositivo]

## Impacto medido

| Dimensión | Impacto | Evidencia |
|---|---|---|
| Productividad | [Completar: horas totales vs. estimación sin IA] | Historial de commits |
| Calidad | Pruebas que cubren propiedades críticas (idempotencia, seguridad de tokens, degradación) | `bff/test`, `app/test`, `app/integration_test` |
| Documentación | Arquitectura con C4 + secuencias, 10 ADRs, operación, resiliencia, contrato de micro-apps | `docs/` |
| Pruebas | 25 pruebas del BFF + [Completar: N] unitarias/widget + 2 flujos E2E | Salida de CI |

## IA dentro del producto

- **Asistente financiero:** con `ANTHROPIC_API_KEY` responde con un LLM a partir de **datos agregados** (sin número de cuenta, cédula ni nombres de comercios). Sin clave o ante fallas, usa un motor de intenciones determinístico, así la función nunca queda caída. La UI indica cuándo la respuesta fue generada con IA.
- **Insights:** se calculan de forma determinística a partir de los movimientos reales (comparación de 30 días contra los 30 anteriores), no con IA, para que sean auditables.

## Lineamientos que seguiría en un equipo

- La IA propone y una persona aprueba: ningún cambio entra sin revisión ni pruebas.
- No compartir datos de clientes reales ni secretos con herramientas externas; usar datos semilla.
- Documentar en el PR cuándo hubo asistencia de IA relevante.
