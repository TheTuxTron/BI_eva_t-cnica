# Kinti · Banca digital personalizada

Plataforma financiera construida en **Flutter** y un **BFF en Node.js**. Incluye:

- onboarding sin agencia;
- cuentas, saldos y movimientos;
- transferencias seguras ante reintentos;
- una experiencia que el servidor adapta a cada tipo de cliente (Server-Driven UI);
- un ecosistema de micro-apps de terceros;
- notificaciones push para ayudar al cliente;
- un asistente financiero para dudas generales;
- resiliencia demostrable ante redes malas y caídas parciales.

> *Kinti* significa colibrí en kichwa, se le dió ese nombre porque relacionamos el colibrí con un animal veloz y eficaz así como nuestro manejo de la plataforma financiero.

| | |
|---|---|
| Arquitectura y diagramas | [`docs/architecture.md`](docs/architecture.md) |
| Decisiones (ADR) | [`docs/adr/`](docs/adr/README.md) |
| Design system y paleta (usando la marca de colores del Banco Internacional) | [`docs/design-system.md`](docs/design-system.md) |
| Revisión funcional por módulo (QA) | [`docs/qa-modulos.md`](docs/qa-modulos.md) |
| Despliegue, operación y monitoreo | [`docs/deployment-operations.md`](docs/deployment-operations.md) |
| Conectividad limitada y degradación | [`docs/resilience.md`](docs/resilience.md) |
| Contrato de micro-apps | [`docs/microapps-contract.md`](docs/microapps-contract.md) |
| API del BFF | [`docs/api.md`](docs/api.md) |
| Uso de IA | [`docs/ai-usage.md`](docs/ai-usage.md) |

## Requisitos del reto → implementación → evidencia

| Requisito | Implementación | Evidencia |
|---|---|---|
| Onboarding y autenticación | Registro en 3 pasos (cédula ecuatoriana módulo 10, mayoría de edad, política de contraseña, términos LOPDP) + OTP + apertura de cuenta. Login con JWT y refresh rotativo con detección de reúso. Tokens en Keystore/Keychain | `features/auth`, `bff/src/routes/auth.js`, `bff/test/auth.test.js`, E2E onboarding |
| Cuentas, saldos y movimientos | Saldo consolidado, cuentas, movimientos paginados por cursor y agrupados por día, filtro por categoría, ocultar saldos | `features/accounts`, `bff/test/accounts.test.js`, `test/features/movements_cubit_test.dart` |
| Personalización dinámica | SDUI: el BFF decide componentes, orden, contenido y tema según **segmento** (perfil), **hora** (contexto), **uso** (comportamiento) y **preferencias**. Campañas y feature flags sin publicar la app. A/B estable. "¿Por qué veo esto?" | `sdui/`, `bff/src/services/personalization.js`, `bff/test/experience.test.js`, `test/widgets/sdui_renderer_test.dart` |
| Integración con servicio/micro-app externo | (1) Micro-app "Simulador financiero" de otro equipo en WebView con bridge versionado y token de alcance mínimo. (2) Tipo de cambio real de Frankfurter/BCE con circuit breaker | `features/microapps`, `bff/public/microapps`, `bff/test/microapps.test.js`, `bff/test/resilience.test.js` |
| Notificaciones push | FCM (si se configura Firebase) + bandeja persistente + respaldo por polling. Deeplinks seguros | `features/notifications`, `bff/src/services/push.js` |
| Monitoreo en producción | Fachada `Telemetry` (logs estructurados + eventos de UX; destino de crashes enchufable, ver ADR-009), `X-Request-Id` extremo a extremo, Prometheus `/metrics`, health checks, SLOs, alertas y runbooks | `core/observability`, `docs/deployment-operations.md` |
| Conectividad limitada, latencia e indisponibilidad (descripción) | Matriz de escenarios y mecanismos | `docs/resilience.md` |
| Conectividad limitada, latencia e indisponibilidad (demostración) | Fault injection en el BFF + panel "Diagnóstico" en la app: carga, reintentos, caché, fallback y recuperación | `features/diagnostics`, `bff/src/middleware/chaos.js`, video |
| Pruebas unitarias, de widgets y E2E | 25 pruebas del BFF; unitarias (interceptores, SWR, cubits, SDUI, bridge); widgets (login, SDUI, banner de conectividad, montos accesibles); **2 flujos E2E contra el BFF real** | `bff/test`, `app/test`, `app/integration_test` |
| Uso de IA documentado | Proceso, aciertos, errores corregidos e impacto | `docs/ai-usage.md` |
| Decisiones de arquitectura | 10 ADRs con problema, alternativas, decisión, trade-offs e impacto | `docs/adr/` |
| Trunk Based Development | Commits pequeños a `main`, Conventional Commits con hook y CI, feature flags en lugar de ramas largas | `docs/adr/0010-trunk-based.md`, `tool/hooks`, `.github/workflows` |
| **Bonus:** asistencia avanzada | Asistente con LLM opcional (datos agregados, sin PII) y respaldo determinístico; insights calculados de movimientos reales | `features/assistant`, `bff/src/services/assistant.js`, `insights.js` |
| **Bonus:** experiencias dinámicas | Inicio, tema, banners y acciones generados por servidor | SDUI |
| **Bonus:** automatizaciones | CI (format, analyze, tests, cobertura, E2E en emulador), imagen Docker a GHCR, hook de commits, script de plataformas, `Makefile` con escenarios de caos | `.github/workflows`, `tool/`, `Makefile` |

## Inicio rápido

**Requisitos:** Node.js 22.13+, Flutter estable (3.29+), Android Studio con un emulador (o Xcode para iOS) y Git.

```bash
git clone <repo> kinti && cd kinti
make hooks                      # activa la validación de Conventional Commits

# 1) Backend (terminal 1)
cd bff && npm ci && npm run dev # http://localhost:8080  ·  datos semilla en memoria

# 2) App (terminal 2)
cd app
./tool/setup_platforms.sh       # genera android/ios y ajusta manifiestos (solo la primera vez)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080   # emulador Android
#   simulador iOS:   --dart-define=API_BASE_URL=http://localhost:8080
#   dispositivo:     --dart-define=API_BASE_URL=http://<IP-de-tu-PC>:8080  (abre el puerto 8080 en el firewall)
```

**Con Docker:** `docker compose up --build` levanta el BFF con datos persistentes en un volumen.

**Usuarios de demostración** (contraseña `Kinti2026!`), también disponibles como chips en la pantalla de login:

| Usuario | Segmento | Qué muestra |
|---|---|---|
| `ana@kinti.ec` | Joven | Saldo en degradé naranja, metas de ahorro, insight de gastos en restaurantes |
| `carlos@kinti.ec` | Premium | Tema café profundo con acento naranja, dos cuentas, inversión primero, tipo de cambio destacado |
| `maria@kinti.ec` | Clásico | Cuenta destino `2200990011` para transferencias |

### Opcionales

| Función | Cómo activarla |
|---|---|
| Push reales (FCM) | Crea un proyecto Firebase y coloca `google-services.json` / `GoogleService-Info.plist`. En el BFF, define `FIREBASE_SERVICE_ACCOUNT` con el JSON de la cuenta de servicio. Sin esto, se usa la bandeja + polling |
| Asistente con LLM | Define `ANTHROPIC_API_KEY` en el BFF |
| BFF público para evaluadores | `render.yaml` (Render, plan free) |

## Pruebas

```bash
cd bff && npm test                       # 25 pruebas: auth, cuentas, idempotencia, SDUI, caos, micro-apps
cd app && flutter analyze && flutter test --coverage
# E2E (BFF corriendo + emulador abierto):
cd app && flutter test integration_test --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

Los dos flujos E2E corren contra el **BFF real** (no mocks):
1. login → inicio personalizado → transferencia → notificación en la bandeja;
2. apertura de cuenta → OTP → inicio con bono de bienvenida.

## Demostrar escenarios degradados

Desde la app: **Perfil → Diagnóstico y resiliencia**. Desde la terminal:

```bash
make chaos-latency       # 3 s ± 1 s en todas las rutas
make chaos-outage-home   # cae el servicio de personalización
make campaign            # publica un banner nuevo para "joven" sin publicar la app
make chaos-normal        # restablece
```

Detalle de cada escenario y del comportamiento esperado: [`docs/resilience.md`](docs/resilience.md).

## Estructura

```
kinti/
├── app/                         Flutter
│   ├── lib/
│   │   ├── app/                 composición: DI, router, shell, sesión, deeplinks, bootstrap
│   │   ├── core/                red, caché SWR, conectividad, observabilidad, almacenamiento seguro
│   │   ├── design_system/       tokens, tema por segmento, componentes accesibles
│   │   ├── sdui/                motor Server-Driven UI (modelos, registro, renderer, fallback)
│   │   └── features/            un módulo por dominio (auth, accounts, transfers, personalization,
│   │                            fx, microapps, notifications, assistant, diagnostics)
│   ├── test/                    unitarias y de widgets
│   ├── integration_test/        E2E
│   └── tool/setup_platforms.sh
├── bff/                         Node.js 22 + Express
│   ├── src/{routes,services,middleware,lib}
│   ├── public/microapps/        micro-app del "otro equipo"
│   └── test/
├── docs/                        arquitectura, ADRs, operación, resiliencia, API, IA
├── .github/workflows/           CI y despliegue
├── tool/hooks/                  Conventional Commits
├── docker-compose.yml · render.yaml · Makefile
```

## Cómo colaborar (Trunk Based Development)

1. Actualiza `main` (`git pull --rebase`) y trabaja en cambios pequeños. Si usas rama, que viva menos de un día.
2. Lo incompleto va detrás de un feature flag (`/v1/config`), no en una rama larga.
3. Usa Conventional Commits, por ejemplo `feat(transfers): ...`, `fix(sdui): ...` o `test(accounts): ...`. El hook (`make hooks`) y el CI los validan.
4. Antes de integrar: `make test`. El CI repite format, analyze, pruebas y E2E.
5. Para agregar un dominio: crea `features/<dominio>/` con `data/`, `presentation/` y un `FeatureModule`, y regístralo en `app/di.dart`.
6. Para agregar un componente SDUI: regístralo desde tu módulo y documenta sus `props`. El servidor solo debe enviarlo a versiones de la app que lo soportan.
