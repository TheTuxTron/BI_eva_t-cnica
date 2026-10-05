# ADR-004 · Server-Driven UI para experiencias sin publicar la app

**Problema.** El negocio necesita incorporar contenidos, campañas, componentes y orden de la experiencia según el perfil, contexto, comportamiento y preferencias del cliente, sin esperar el ciclo de revisión de las tiendas (días) ni depender de que el usuario actualice.

**Alternativas evaluadas.**
1. Solo Remote Config / feature flags (on/off).
2. Code push (p. ej. Shorebird): parchear código Dart en caliente.
3. Pantallas completas en WebView.
4. **SDUI: el servidor decide qué componentes, en qué orden y con qué contenido; la app trae un catálogo nativo y seguro de componentes.**

**Decisión.** Opción 4 combinada con feature flags. El BFF expone `GET /v1/experience/home` con `schemaVersion`, `theme`, `sections[]` y `meta.reasons` (explicabilidad). Cada feature registra sus componentes en el `SduiRegistry`.

**Trade-offs.**
- (+) Las campañas, el orden, el tema por segmento y los experimentos A/B se cambian desde backoffice al instante. La UI sigue siendo nativa, accesible y rápida.
- (+) La degradación es explícita: un componente desconocido se omite, uno que falla se aísla, un esquema más nuevo usa la caché, y si no hay caché se usa la experiencia embebida (`fallback_home.dart`).
- (−) Solo se pueden componer piezas que ya existen en el binario. Un componente nuevo sí requiere publicar, aunque su aparición luego la controla el servidor.
- (−) Hay que versionar el esquema y mantener compatibilidad hacia atrás.
- (−) Code push permitiría cambios de lógica, pero tiene riesgos de cumplimiento con las tiendas y de auditoría en banca.

**Impacto a largo plazo.** El catálogo se convierte en el "lenguaje" de la experiencia: producto compone pantallas, y el motor de reglas puede reemplazarse por un CDP o un modelo de recomendación sin tocar la app. La siguiente evolución es SDUI para más pantallas (ofertas, onboarding por segmento) y acciones declarativas.
