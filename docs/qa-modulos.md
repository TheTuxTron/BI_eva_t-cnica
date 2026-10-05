# Revisión funcional por módulo

Fecha: 4 de octubre de 2026. **Backend:** 29 pruebas automatizadas en verde, incluido un recorrido completo de cliente nuevo y pruebas de regresión de los defectos encontrados. **App:** pruebas unitarias, de widgets y E2E descritas en el README. Este documento resume cada módulo, cómo se verificó, qué defectos aparecieron y cómo se corrigieron.

## Resumen

| Módulo | Estado | Verificación automática | Defectos encontrados → corrección |
|---|---|---|---|
| Autenticación y sesión | ✅ | `auth.test.js` (6), `interceptors_test.dart`, `login_page_test.dart` | Usuario inexistente con token válido daba 500 → ahora 401 y vuelve a login |
| Onboarding (apertura de cuenta) | ✅ | `auth.test.js`, `regressions.test.js` (recorrido completo), E2E onboarding | Datos perdidos al reiniciar el BFF (base en memoria) → SQLite en archivo; errores inesperados dejaban el botón cargando → los cubits capturan cualquier excepción; detalle técnico visible en debug |
| Cuentas y movimientos | ✅ | `accounts.test.js`, `movements_cubit_test.dart` | — |
| Transferencias | ✅ | `accounts.test.js` (idempotencia, fondos), `transfer_cubit_test.dart`, E2E crítico | — |
| Personalización (SDUI) | ✅ | `experience.test.js` (7), `sdui_models_test.dart`, `sdui_renderer_test.dart`, `home_experience_cubit_test.dart` | — |
| Micro-app (simulador) | ✅ | `microapps.test.js`, `regressions.test.js`, pruebas del bridge y de la URL | **Error de conexión en el emulador**: el BFF devolvía `localhost` → URL deducida del `Host` + salvaguarda en la app |
| Tipo de cambio (tercero) | ✅ | `resilience.test.js` | — |
| Notificaciones | ✅ | `accounts.test.js` (aviso al destinatario), E2E crítico (bandeja) | — |
| Asistente | ✅ | `experience.test.js`, `regressions.test.js` | — |
| Resiliencia / diagnóstico | ✅ | `resilience.test.js` (5), `interceptors_test.dart`, `swr_test.dart`, `connectivity_banner_test.dart` | — |
| Build Android | ✅ | Compilación en emulador | Dio reciente (`transformTimeout`) y Sentry incompatible con Kotlin 2 → corregidos (ADR-009) |

## Detalle y prueba manual sugerida

### Autenticación y sesión
- **Qué hace:** login con correo o cédula; refresh transparente; detección de reúso de refresh token; logout que borra tokens y caché.
- **Prueba manual:** entrar con los tres usuarios demo; cerrar sesión; reiniciar la app (debe mantener la sesión); reiniciar el BFF y seguir usando la app (los datos persisten).

### Onboarding
- **Qué hace:** tres pasos con validación local y del servidor; OTP (en modo demo se muestra en pantalla); apertura de cuenta con bono de $10 y notificación de bienvenida.
- **Prueba manual:**
  1. Ingresa una cédula inválida (debe rechazarla) y luego una válida.
  2. Avanza los pasos y crea la cuenta.
  3. En la pantalla de OTP toca "Usar" y luego "Verificar".
  4. El inicio debe mostrar **$10,00**.
  5. Repite con el mismo correo: debe indicar que ya existe.
- **Si aparece un error de conexión:** en debug, debajo del mensaje se ve la causa técnica (`[debug] NetworkFailure: ...`) y un código de soporte. Con ese código se busca la petición en la consola del BFF.

### Cuentas y movimientos
- **Prueba manual:** abrir una cuenta; hacer scroll hasta el final (paginación); tocar el insight del inicio para ver movimientos filtrados; ocultar y mostrar saldos.

### Transferencias
- **Prueba manual:**
  1. Transfiere de Ana a `2200990011` y verifica el titular "María Y.".
  2. Prueba un monto mayor al saldo (debe bloquearlo).
  3. Con el preset "Errores intermitentes", transfiere y comprueba que el saldo baja **una sola vez**.

### Personalización
- **Prueba manual:**
  1. Compara el inicio de Ana (degradé naranja, "Meta de ahorro") con el de Carlos (café, "Invertir" primero, tipo de cambio arriba).
  2. En Perfil, oculta módulos y revisa "¿Por qué veo este inicio?".
  3. Ejecuta `make campaign` (o el `curl` del Makefile) y haz pull-to-refresh con Ana.

### Micro-app (simulador)
- **Prueba manual:**
  1. Abre "Simula tu crédito" o "Meta de ahorro".
  2. Cambia entre pestañas y mueve el plazo: el cálculo viene del BFF con la tasa del segmento.
  3. Toca "Consultar con el asistente" (debe navegar por el bridge) y luego "Volver a mi banca".

### Tipo de cambio
- **Prueba manual:** con internet, deben verse las tasas del BCE. Con el preset "Cae tipo de cambio", solo esa tarjeta se degrada.

### Notificaciones
- **Prueba manual:** transfiere de Ana a María; entra como María y revisa la bandeja y el badge. Sin Firebase configurado, los avisos llegan por polling cada 30 s en primer plano y al volver a la app.

### Asistente
- **Prueba manual:** pregunta "¿Cuál es mi saldo?", "¿En qué gasto más?" y "¿Cómo puedo ahorrar más?". Este último ofrece abrir el simulador.

### Resiliencia
- **Prueba manual:** sigue la matriz de `docs/resilience.md`, con los presets de Perfil → Diagnóstico y el modo avión.

## Limitaciones conocidas (declaradas, no defectos)
- El OTP se muestra en pantalla porque no hay proveedor SMS (`EXPOSE_OTP=true`, solo en demo).
- Las push del sistema requieren configurar Firebase. Sin él se usa la bandeja con polling.
- Sin un proveedor de crashes conectado (ADR-009), la telemetría queda en logs estructurados y en eventos al BFF.
- Las transferencias son solo entre cuentas Kinti.
