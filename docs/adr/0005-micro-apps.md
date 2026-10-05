# ADR-005 · Micro-apps externas vía WebView + bridge con token de alcance mínimo

**Problema.** El ecosistema debe integrar servicios propios o de terceros (simuladores, seguros, marketplace) mantenidos por otros equipos y con su propio ciclo de despliegue, sin comprometer la seguridad de la sesión bancaria.

**Alternativas evaluadas.**
1. Integrar cada servicio como código Flutter dentro de la app.
2. Deep link a una app externa.
3. WebView con el access token del usuario en la URL.
4. **WebView con contrato de mensajes versionado y un token propio de alcance mínimo por micro-app.**

**Decisión.** Opción 4. Flujo: la app pide `POST /v1/microapps/{id}/session`; el BFF emite un JWT con `aud=microapp:{id}`, scopes acotados y TTL de 5 minutos; la app lo entrega por el bridge (`window.kintiReceive`), nunca por URL. La micro-app llama solo a su API (`/v1/microapp-api/...`), que rechaza el token principal. Los mensajes micro-app → host se validan (versión, tipo, rutas en lista blanca) y la navegación de la WebView se restringe al origen registrado.

**Trade-offs.**
- (+) El despliegue de la micro-app es independiente, puede ser de un tercero, y un token filtrado tiene impacto acotado (no puede leer cuentas ni transferir).
- (−) La experiencia web no es 100 % nativa y hay que alinear el estilo (se pasa el tema por contexto). Además depende de la WebView del sistema.
- (−) Una integración nativa daría mejor experiencia, pero acopla el ciclo de despliegue del tercero al de la app.

**Impacto a largo plazo.** El catálogo `/v1/microapps` funciona como registro del ecosistema: alta y baja de aliados sin publicar la app, contrato versionado (`v: 1`) y scopes por aliado. Las micro-apps críticas pueden migrar a módulos nativos cuando lo justifique su uso.
