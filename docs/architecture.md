# Arquitectura de Kinti

Kinti es una plataforma financiera 100 % digital: onboarding sin agencia, cuentas y movimientos, transferencias, una experiencia que se adapta a cada cliente y un ecosistema de servicios propios y de terceros. Este documento describe la solución, sus flujos críticos, supuestos, riesgos y estrategia de escalamiento. Las decisiones con sus alternativas descartadas están en [`adr/`](adr/README.md).

## 1. Contexto (C4 nivel 1)

```mermaid
flowchart LR
  cliente([Cliente<br/>móvil Android/iOS])
  equipo([Equipos de producto<br/>y marketing])
  subgraph kinti[Plataforma Kinti]
    app[App Flutter]
    bff[BFF móvil]
  end
  fcm[(Firebase Cloud<br/>Messaging)]
  fx[(Frankfurter / BCE<br/>tipo de cambio)]
  llm[(LLM opcional<br/>asistente)]
  sentry[(Sentry)]
  prom[(Prometheus /<br/>Grafana)]
  core[(Core bancario<br/>— simulado con SQLite)]

  cliente --> app
  app -->|HTTPS + JWT| bff
  equipo -->|campañas, flags| bff
  bff --> core
  bff --> fx
  bff --> llm
  bff --> fcm --> app
  app --> sentry
  prom -->|scrape /metrics| bff
```

## 2. Contenedores (C4 nivel 2)

```mermaid
flowchart TB
  subgraph device[Dispositivo]
    flutter[App Flutter<br/>BLoC · go_router · Dio]
    webview[Micro-app web<br/>en WebView]
    secure[(Keystore / Keychain<br/>tokens)]
    cache[(Caché local<br/>por usuario)]
    flutter <-->|bridge v1| webview
    flutter --- secure
    flutter --- cache
  end
  subgraph backend[Backend]
    bff[BFF Node.js 22 · Express]
    db[(SQLite<br/>→ core bancario)]
    static[Hosting de micro-apps]
    bff --- db
    bff --- static
  end
  flutter -->|/v1/* access token| bff
  webview -->|/v1/microapp-api/* token de alcance mínimo| bff
  bff -->|circuit breaker| fx[(Frankfurter)]
  bff -->|opcional| fcm[(FCM)]
```

| Contenedor | Responsabilidad | Tecnología |
|---|---|---|
| App Flutter | UI nativa, estado, caché offline, resiliencia de red, contenedor de micro-apps, telemetría | Flutter 3.29+, flutter_bloc, go_router, Dio, get_it |
| BFF | Auth, agregación por dominio, SDUI, idempotencia, notificaciones, tokens de micro-apps, fault injection, métricas | Node.js 22, Express, zod, pino, prom-client, `node:sqlite` |
| Micro-app "Simulador financiero" | Servicio de otro equipo con despliegue independiente | HTML/JS estático + API propia en el BFF |

## 3. Componentes de la app (C4 nivel 3)

```mermaid
flowchart TB
  subgraph app[lib/]
    direction TB
    subgraph appcore[app/ — composición]
      di[di.dart<br/>contenedor + módulos]
      router[router.dart<br/>guards de sesión]
      scope[session_scope.dart<br/>estado por usuario]
      deeplinks[deep_links.dart<br/>lista blanca]
    end
    subgraph core[core/ — transversal]
      net[network<br/>ApiClient · interceptores]
      cachec[cache<br/>Resource · SWR]
      conn[connectivity]
      obs[observability<br/>Telemetry]
    end
    ds[design_system/]
    sdui[sdui/<br/>registry · renderer · fallback]
    subgraph features[features/ — un módulo por dominio]
      auth[auth]
      accounts[accounts]
      transfers[transfers]
      perso[personalization]
      fxm[fx]
      micro[microapps]
      notif[notifications]
      assist[assistant]
    end
  end
  features -->|registran rutas, DI y componentes| appcore
  features --> core
  features --> ds
  features --> sdui
  sdui --> ds
  appcore --> core
```

**Regla de dependencias:** `features → (core, design_system, sdui)`. El núcleo nunca importa features. Las features se comunican por deeplinks y cubits compartidos de sesión, no importando internals de otros dominios (excepto `transfers → accounts.data`, declarado y deliberado).

**Capas dentro de cada dominio:** `data/` (modelos + repositorio, que es el único que conoce HTTP y caché) y `presentation/` (cubits + widgets). Los cubits dependen de repositorios, nunca de Dio.

## 4. Flujos críticos

### 4.1 Inicio personalizado con degradación en tres niveles

```mermaid
sequenceDiagram
  participant U as Cliente
  participant C as HomeExperienceCubit
  participant L as Caché local
  participant B as BFF /v1/experience/home
  U->>C: abre la app
  C->>L: lee última experiencia
  L-->>C: experiencia guardada (si existe)
  C-->>U: render inmediato + "actualizando"
  C->>B: GET (reintentos con backoff)
  alt servicio OK
    B-->>C: secciones + tema del segmento + reasons
    C-->>U: experiencia fresca, tema aplicado
  else falla y hay caché
    C-->>U: mantiene caché + "datos de hace X min"
  else falla y NO hay caché
    C-->>U: experiencia embebida (saldo + transferir)
  end
```

### 4.2 Transferencia idempotente (flujo E2E crítico)

```mermaid
sequenceDiagram
  participant U as Cliente
  participant T as TransferCubit
  participant R as RetryInterceptor
  participant B as BFF /v1/transfers
  U->>T: Continuar
  T->>T: genera Idempotency-Key (1 por intención)
  U->>T: Confirmar
  T->>R: POST + Idempotency-Key
  R->>B: intento 1
  B--xR: timeout (débito YA aplicado)
  R->>B: intento 2 (misma clave)
  B-->>R: 201 + Idempotent-Replayed: true
  R-->>T: comprobante
  T-->>U: ¡Transferencia enviada! (un solo débito)
  Note over T,B: Si todos los intentos fallan → estado "incierto".<br/>"Reintentar" usa la misma clave: es seguro.
```

### 4.3 Sesión: refresh concurrente y reúso detectado

```mermaid
sequenceDiagram
  participant A as Requests concurrentes
  participant I as AuthInterceptor (cola)
  participant B as BFF
  A->>I: 3 requests con access vencido
  I->>B: request 1
  B-->>I: 401
  I->>B: POST /auth/refresh (una sola vez)
  B-->>I: nuevo access + refresh rotado
  I->>B: reintenta 1, 2, 3 con el token nuevo
  Note over B: Si llega un refresh ya rotado → se revoca toda la familia<br/>(posible robo) y la app vuelve a login con aviso.
```

### 4.4 Micro-app externa

```mermaid
sequenceDiagram
  participant H as App (host)
  participant B as BFF
  participant W as Micro-app (WebView)
  H->>B: POST /v1/microapps/simulador-credito/session
  B-->>H: token aud=microapp, scope=credit.simulate, TTL 5 min
  H->>W: carga URL (sin token)
  W->>H: {v:1,type:"ready"}
  H->>W: kintiReceive({type:"session", token, context})
  W->>B: POST /v1/microapp-api/.../simulate (token limitado)
  B-->>W: tabla de amortización (tasa según segmento)
  W->>H: {type:"navigate", route:"/assistant"} → validado contra lista blanca
```

### 4.5 Notificaciones

```mermaid
flowchart LR
  ev[Evento: transferencia,<br/>onboarding, campaña] --> notify[push.notify]
  notify --> inbox[(Bandeja persistida)]
  notify -->|si hay credenciales| fcm[FCM] --> so[Notificación del SO] -->|tap + deeplink| app
  inbox -->|polling en primer plano<br/>30 s sin FCM · 2 min con FCM| app[App: banner in-app + badge]
```

## 5. Dependencias relevantes

| Dependencia | Uso | Riesgo si falla | Mitigación |
|---|---|---|---|
| Frankfurter (BCE) | Tipo de cambio real | Módulo FX sin datos | Circuit breaker + caché vencida marcada; el resto del inicio no se afecta |
| FCM | Push del SO | Sin push del sistema | Bandeja + polling; canal visible en Ajustes |
| LLM (opcional) | Respuestas del asistente | Sin respuestas generativas | Motor de intenciones determinístico como respaldo; contexto agregado, sin PII |
| WebView del sistema | Micro-apps | Micro-app no carga | Timeout de `ready` (12 s) + error con reintento |
| Core bancario (SQLite en la prueba) | Saldos, movimientos | Sin datos frescos | Caché SWR en la app; outage por dominio demostrable |

## 6. Seguridad

- **Tokens:** access JWT de 15 min y refresh opaco rotativo con detección de reúso por familia. Se guardan en Keystore/Keychain (`flutter_secure_storage`), nunca en preferencias.
- **Contraseñas:** scrypt con sal. Login con rate limit y el mismo mensaje para "usuario no existe" y "contraseña incorrecta".
- **Mínimo privilegio para terceros:** token de micro-app con audiencia y scope propios, entregado por el bridge y no por URL. Mensajes validados y navegación restringida al origen.
- **Datos:** la caché local está aislada por usuario y se borra al cerrar sesión. Sentry con `sendDefaultPii=false`. Logs del BFF con redacción de `authorization`, contraseñas y tokens. El asistente LLM recibe solo agregados.
- **Validación:** zod en el BFF (fuente de verdad) más validación local para feedback inmediato (cédula módulo 10, mayoría de edad, políticas de contraseña).
- **Red:** HTTP en claro solo en builds debug; release exige HTTPS. Pendiente para producción: certificate pinning y detección de root/jailbreak (R-06).

## 7. Supuestos

1. **S-01:** el core bancario se simula con SQLite dentro del BFF. Los repositorios del BFF son el punto de reemplazo por adaptadores al core real.
2. **S-02:** el OTP se devuelve en la respuesta solo con `EXPOSE_OTP=true` (demo). En producción se integra un proveedor SMS y la bandera se desactiva.
3. **S-03:** las transferencias son internas (entre cuentas Kinti). Las interbancarias (SPI/BCE) quedan fuera del alcance.
4. **S-04:** la segmentación usa reglas explícitas y auditables (edad, saldo). En producción vendría de un CDP o modelo.
5. **S-05:** la app apunta a Android e iOS; la micro-app requiere WebView, que no está disponible en Flutter web.

## 8. Riesgos técnicos

| ID | Riesgo | Prob. | Impacto | Mitigación / estado |
|---|---|---|---|---|
| R-01 | Doble débito por reintentos | Media | Crítico | Idempotency-Key extremo a extremo (implementado, con pruebas) |
| R-02 | Esquema SDUI incompatible con versiones viejas de la app | Media | Alto | `schemaVersion`, componentes desconocidos omitidos, caché y fallback embebido |
| R-03 | Micro-app comprometida | Baja | Alto | Token de alcance mínimo, validación de mensajes, restricción de origen |
| R-04 | Caché local sin cifrar en dispositivos rooteados | Media | Medio | Aislamiento por usuario y borrado al logout; cifrado con clave en Keystore en producción |
| R-05 | BFF como punto único de falla | Media | Alto | Stateless salvo la DB; réplicas horizontales detrás de LB, health checks y rollback |
| R-06 | MITM / dispositivos comprometidos | Baja | Alto | HTTPS obligatorio en release; pendiente: pinning, RASP y attestation (Play Integrity / App Attest) |
| R-07 | Crecimiento de la tabla de idempotencia | Alta | Bajo | TTL 24–72 h con job de limpieza |
| R-08 | Dependencia de proveedor FX gratuito | Media | Bajo | Circuit breaker + stale; proveedor contratado con SLA en producción |

## 9. Estrategia de escalamiento

**Tráfico.** El BFF es stateless (JWT), así que escala horizontalmente detrás de un balanceador. Los cuellos de botella en orden:
1. Base de datos: SQLite → PostgreSQL/core real con pool de conexiones y réplicas de lectura para movimientos.
2. Idempotencia y rate limit en almacén compartido (Redis).
3. Caché de la experiencia por segmento + usuario (TTL 5 min, invalidada al cambiar preferencias o campañas).
4. Tipo de cambio cacheado globalmente (ya lo está, TTL 1 h).

**Organización.**
1. Extraer cada `features/<dominio>` a un paquete con CODEOWNERS (ADR-002).
2. Dividir el BFF por dominio detrás de un gateway, manteniendo los paths `/v1/<dominio>`.
3. Publicar el design system y el motor SDUI como paquetes versionados.
4. Registrar aliados en el catálogo de micro-apps con scopes y contrato versionado.

**Producto.**
1. SDUI para más pantallas.
2. Personalización con modelo (CDP + experimentos ya soportados vía buckets estables).
3. Rollouts graduales combinando staged rollout de tiendas, flags y SDUI.
