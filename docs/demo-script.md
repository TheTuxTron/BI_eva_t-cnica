# Partes del video de demostración 

1. **Contexto:** Qué es Kinti y la arquitectura en una frase: app Flutter + BFF; muestra el diagrama de contenedores de `docs/architecture.md`.
2. **Onboarding:** Abrir cuenta: validación de cédula en vivo (prueba primero una inválida), mayor de edad, reglas de contraseña, OTP en modo demo, y llegada al inicio con el bono de $10 y la notificación de bienvenida.
3. **Personalización:**
   - Cierra sesión y entra como joven: saldo en degradé naranja, "Meta de ahorro" y su insight de gastos.
   - Cierra sesión y entra como premium: tema café de marca con acento naranja, "Invertir" primero y tipo de cambio arriba.
   - Perfil → "¿Por qué veo este inicio?".
   - Oculta "Tipo de cambio" y vuelve al inicio: desapareció.
4. **Cuentas y movimientos** Detalle de cuenta, scroll infinito por cursor y agrupación por día. 
5. **Transferencia + push** Transfiere de a otras cuentas: verificación del titular, confirmación y éxito. Muestra la notificación y el saldo actualizado. Entra a la otra cuenta y muestra "Recibiste dinero".
6. **Micro-app:** Abre el simulador (otro equipo, despliegue independiente). Cambia entre crédito, inversión y ahorro: la tasa depende del segmento. Toca "Consultar con el asistente", que navega al host por el bridge. Pregunta al asistente "¿En qué gasto más?".
7. **Resiliencia** Perfil → Diagnóstico:
   - **Latencia alta:** skeletons y progreso visibles.
   - **Errores intermitentes:** muestra una transferencia; se completa con reintentos y un solo débito.
   - **Cae personalización:** el inicio queda desde caché. Luego "Borrar caché" y se reabre: aparece la experiencia simplificada.
   - **Cae tipo de cambio:** solo esa tarjeta se degrada.
   - **Modo avión:** banner "Sin conexión" y datos guardados. Quítalo: "Conexión restablecida" y recarga automática.
   - **Normal.**
