# Contrato de micro-apps (bridge v1)

Las micro-apps son aplicaciones web de otros equipos o aliados que se ejecutan dentro de Kinti en una WebView.

## Registro

`GET /v1/microapps` devuelve `id`, `name`, `version`, `owner`, `path`, `scopes` y `allowedNavigation`. Hoy el registro está en código (`MICROAPPS` en el BFF); en producción iría en un backoffice.

## Sesión

1. El host pide `POST /v1/microapps/{id}/session` con el access token del usuario.
2. El BFF responde `{ token, expiresIn, url, allowedNavigation, context }`.
   - `token`: JWT con `aud=microapp:{id}`, `scp=[...]`, TTL 5 min. **No sirve para la API principal.**
   - `context`: datos mínimos de UX (`firstName`, `segment`, `theme`). Nunca números de cuenta ni cédula.
3. El host carga `url` **sin** el token. El token se entrega por el bridge cuando la micro-app avisa que está lista.

## Mensajes

Todos los mensajes son JSON con `v: 1`.

| Dirección | `type` | Campos | Validación del host |
|---|---|---|---|
| micro-app → host | `ready` | — | Dispara el envío de la sesión |
| micro-app → host | `navigate` | `route` | Solo rutas de `allowedNavigation` |
| micro-app → host | `track` | `event` | Debe empezar con `microapp_` |
| micro-app → host | `close` | — | Cierra la micro-app |
| micro-app → host | `session_expired` | — | El host emite un token nuevo |
| host → micro-app | `session` | `token`, `apiBase`, `context` | Vía `window.kintiReceive(msg)` |

- **Canal micro-app → host:** `window.KintiHost.postMessage(JSON.stringify(msg))`.
- **Canal host → micro-app:** `window.kintiReceive(msg)`.

## Reglas de seguridad del host

- Navegación restringida al origen de la micro-app; los intentos externos se bloquean y se reportan.
- Mensajes de más de 4 KB, con versión desconocida o de tipo no permitido se rechazan y se reportan (`microapp_message_rejected`).
- Si no llega `ready` en 12 s, se muestra error con reintento.

## Desarrollo standalone

La micro-app se puede abrir en un navegador con `?devToken=<token>` para desarrollarla sin la app.
