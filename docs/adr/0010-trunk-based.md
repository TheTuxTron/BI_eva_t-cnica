# ADR-010 · Trunk Based Development con feature flags

**Problema.** Se busca integrar de forma continua, evitar ramas largas con merges dolorosos y poder desplegar `main` en cualquier momento.

**Alternativas evaluadas.** GitFlow, GitHub Flow con ramas de larga duración y Trunk Based Development.

**Decisión.** Trunk Based Development:
- commits pequeños y frecuentes a `main`, o ramas de vida corta (menos de un día) integradas mediante PR;
- mensajes con Conventional Commits, validados por un hook local (`tool/hooks`) y por el CI;
- funcionalidades incompletas ocultas detrás de feature flags remotos (`/v1/config`, `PUT /v1/admin/flags`) en lugar de mantenerlas en ramas;
- CI en cada push: convención de commits, pruebas del BFF, formato, análisis estático y pruebas de la app. El E2E en emulador se ejecuta bajo demanda (ver *Trade-offs*).

**Trade-offs.**
- (+) Integración continua real, historial legible y despliegues pequeños de bajo riesgo.
- (−) Exige disciplina: pruebas rápidas, flags y revisión ágil. Los flags deben retirarse cuando dejan de usarse.
- (−) El E2E en emulador dentro de GitHub Actions resultó inestable: sin GPU, el emulador no renderizaba y el job quedaba colgado. Se movió a un workflow manual (`e2e.yml`) con renderizado por software y timeout de 45 minutos, y se valida en local antes de integrar. En un equipo se usaría Firebase Test Lab o dispositivos reales.

**Impacto a largo plazo.** Habilita el despliegue continuo del BFF y releases frecuentes de la app con rollouts graduales (staged rollout de las tiendas, flags y SDUI).
