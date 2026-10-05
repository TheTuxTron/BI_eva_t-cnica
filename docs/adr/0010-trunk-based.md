# ADR-010 · Trunk Based Development con feature flags

**Problema.** Se busca integrar continuamente, evitar ramas largas con merges dolorosos y poder desplegar `main` en cualquier momento.

**Alternativas evaluadas.** GitFlow, GitHub Flow con ramas largas y **Trunk Based Development**.

**Decisión.** TBD:
- commits pequeños y frecuentes a `main`, o ramas de vida corta (menos de 1 día) con PR;
- Conventional Commits verificados con un hook local y en CI;
- funcionalidades incompletas ocultas detrás de feature flags remotos (`/v1/config`, `PUT /v1/admin/flags`) en lugar de ramas;
- CI completo en cada push y E2E en `main`.

**Trade-offs.**
- (+) Integración continua real, historial legible y despliegues pequeños de bajo riesgo.
- (−) Exige disciplina: tests rápidos, flags y revisión ágil. Los flags deben retirarse cuando dejan de usarse.

**Impacto a largo plazo.** Habilita despliegue continuo del BFF y releases frecuentes de la app con rollouts graduales (staged rollout de tiendas + flags + SDUI).
