# ADR-002 · Módulos por dominio con contrato `FeatureModule`

**Problema.** La plataforma debe evolucionar hacia múltiples dominios administrados por equipos independientes, sin que cada cambio obligue a tocar el núcleo de la app ni genere conflictos constantes entre equipos.

**Alternativas evaluadas.**
1. Monolito por capas (`/screens`, `/blocs`, `/services` globales).
2. Paquetes Dart separados desde el día 1 (melos / pub workspaces).
3. Micro-frontends móviles completos (cada dominio con su propio runtime).
4. **Feature-first dentro de la app con un contrato explícito (`FeatureModule`) y fronteras listas para extraerse a paquetes.**

**Decisión.** Opción 4. Cada dominio (`auth`, `accounts`, `transfers`, `personalization`, `fx`, `microapps`, `notifications`, `assistant`) tiene `data/` y `presentation/` propios y un módulo que declara:
- sus dependencias (`registerDependencies`),
- sus rutas a pantalla completa (`routes`),
- sus componentes del catálogo SDUI (`registerComponents`).

El núcleo (`core/`, `design_system/`, `sdui/`) no depende de ninguna feature. Agregar un dominio = agregar un módulo a la lista en `app/di.dart`.

**Trade-offs.**
- (+) Bajo costo inicial, navegación del código simple y fronteras claras verificables en code review.
- (−) Sin paquetes separados, el compilador no impide que una feature importe internals de otra. Se mitiga con revisión y, a futuro, con reglas de lint (`import_lint`/`dependency_validator`).
- (−) Las micro-apps completas (opción 3) darían despliegue independiente real, pero multiplican el tamaño del binario y la complejidad. Ese caso se cubre con el ADR-005.

**Impacto a largo plazo.** Ruta de evolución sin reescritura: (1) mover cada `features/<dominio>` a `packages/<dominio>` con pub workspaces; (2) CODEOWNERS por paquete; (3) el design system y el motor SDUI se publican como paquetes versionados consumidos por todos los equipos.
