# Guion sugerido para el video de demostración (8–10 min)

**Preparación:** BFF corriendo (`make bff`), emulador abierto y app instalada (`make app`). Si te dejan, ten una terminal visible para los comandos `make`.

1. **(0:00) Contexto, 30 s.** Qué es Kinti y la arquitectura en una frase: app Flutter + BFF; muestra el diagrama de contenedores de `docs/architecture.md`.
2. **(0:30) Onboarding, 1 min.** Abrir cuenta: validación de cédula en vivo (prueba primero una inválida), mayor de edad, reglas de contraseña, OTP en modo demo, y llegada al inicio con el bono de $10 y la notificación de bienvenida.
3. **(1:30) Personalización, 2 min.**
   - Cierra sesión y entra como **Ana** (joven): tema violeta, "Meta de ahorro" y su insight de gastos.
   - Cierra sesión y entra como **Carlos** (premium): tema azul y dorado, "Invertir" primero y tipo de cambio arriba.
   - Perfil → "¿Por qué veo este inicio?".
   - Oculta "Tipo de cambio" y vuelve al inicio: desapareció.
   - **Sin publicar la app:** ejecuta `make campaign` y haz pull-to-refresh con Ana: aparece el banner nuevo.
4. **(3:30) Cuentas y movimientos, 1 min.** Detalle de cuenta, scroll infinito por cursor y agrupación por día. Toca el insight para abrir movimientos filtrados por categoría.
5. **(4:30) Transferencia + push, 1,5 min.** Transfiere de Ana a María (2200990011): verificación del titular, confirmación y éxito. Muestra la notificación y el saldo actualizado. Entra como María y muestra "Recibiste dinero".
6. **(6:00) Micro-app, 1 min.** Abre el simulador (otro equipo, despliegue independiente). Cambia entre crédito, inversión y ahorro: la tasa depende del segmento. Toca "Consultar con el asistente", que navega al host por el bridge. Pregunta al asistente "¿En qué gasto más?".
7. **(7:00) Resiliencia, 2 min.** Perfil → Diagnóstico:
   - **Latencia alta:** skeletons y progreso visibles.
   - **Errores intermitentes:** haz una transferencia; se completa con reintentos y un solo débito.
   - **Cae personalización:** el inicio queda desde caché. Luego "Borrar caché" y reabre: aparece la experiencia simplificada.
   - **Cae tipo de cambio:** solo esa tarjeta se degrada.
   - **Modo avión:** banner "Sin conexión" y datos guardados. Quítalo: "Conexión restablecida" y recarga automática.
   - **Normal.**
8. **(9:00) Calidad, 1 min.** Corre `npm test` y `flutter test` (o muestra el CI en verde), enseña el historial de commits y menciona `docs/ai-usage.md`.
