import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kinti/app/bootstrap.dart';
import 'package:kinti/app/env.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Flujos E2E contra el BFF real (no mocks). Requiere el BFF corriendo:
///   cd bff && npm run dev
///   cd app && flutter test integration_test --dart-define=API_BASE_URL=http://10.0.2.2:8080
const _env = AppEnv(
  apiBaseUrl: String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8080'),
  flavor: 'e2e',
  enableDevTools: true,
);

/// Textos visibles en pantalla: se incluyen en el mensaje de fallo para diagnosticar rápido.
String _screenTexts() => find
    .byType(Text)
    .evaluate()
    .map((e) => (e.widget as Text).data)
    .whereType<String>()
    .where((s) => s.trim().isNotEmpty)
    .take(25)
    .join(' | ');

/// pumpAndSettle no sirve con animaciones infinitas (skeletons/progress); se espera por un finder.
Future<void> pumpUntil(WidgetTester t, Finder f, {Duration timeout = const Duration(seconds: 25)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 200));
    if (f.evaluate().isNotEmpty) return;
  }
  fail('No apareció: $f\nEn pantalla: ${_screenTexts()}');
}

/// Cierra el teclado: con el teclado abierto cambian el layout y las posiciones de los botones.
Future<void> hideKeyboard(WidgetTester t) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await t.pump(const Duration(milliseconds: 400));
}

Future<void> fill(WidgetTester t, Finder f, String text) async {
  await pumpUntil(t, f);
  await t.ensureVisible(f);
  await t.pump(const Duration(milliseconds: 150));
  await t.enterText(f, text);
  await t.pump(const Duration(milliseconds: 250));
}

Future<void> tapOn(WidgetTester t, Finder f) async {
  await hideKeyboard(t);
  await pumpUntil(t, f);
  await t.ensureVisible(f);
  await t.pump(const Duration(milliseconds: 200));
  await t.tap(f);
  await t.pump(const Duration(milliseconds: 300));
}

Future<void> freshStart(WidgetTester t) async {
  // Falla rápido y con un mensaje claro si el BFF no responde.
  try {
    await Dio().get<dynamic>('${_env.apiBaseUrl}/health/ready');
  } catch (e) {
    fail('El BFF no responde en ${_env.apiBaseUrl}. ¿Está corriendo "npm run dev" en bff/? Detalle: $e');
  }
  await const FlutterSecureStorage().deleteAll();
  final prefs = await SharedPreferences.getInstance();
  for (final k in prefs.getKeys().where((k) => k.startsWith('kc:')).toList()) {
    await prefs.remove(k);
  }
  // La app instala su manejador global de errores (telemetría); en pruebas se restaura el del framework.
  final testErrorHandler = FlutterError.onError;
  await bootstrap(env: _env);
  FlutterError.onError = testErrorHandler;
  await pumpUntil(t, find.byKey(const Key('welcome_login')));
}

String _validCedula(Random r) {
  final nine = '17${r.nextInt(6)}${List.generate(6, (_) => r.nextInt(10)).join()}';
  var sum = 0;
  for (var i = 0; i < 9; i++) {
    var d = int.parse(nine[i]) * (i.isEven ? 2 : 1);
    if (d > 9) d -= 9;
    sum += d;
  }
  return '$nine${(10 - sum % 10) % 10}';
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('E2E crítico: login → inicio personalizado → transferencia → notificación', (t) async {
    await freshStart(t);
    await tapOn(t, find.byKey(const Key('welcome_login')));
    await fill(t, find.byKey(const Key('login_username')), 'ana@kinti.ec');
    await fill(t, find.byKey(const Key('login_password')), 'Kinti2026!');
    await tapOn(t, find.byKey(const Key('login_submit')));

    // Inicio dirigido por servidor para el segmento "joven".
    await pumpUntil(t, find.textContaining('Ana'));
    await pumpUntil(t, find.text('Meta de ahorro'));

    await tapOn(t, find.text('Transferir').first);
    await fill(t, find.byKey(const Key('transfer_to')), '2200990011');
    await pumpUntil(t, find.textContaining('Titular: María Y.'));
    await fill(t, find.byKey(const Key('transfer_amount')), '1.25');
    await fill(t, find.byKey(const Key('transfer_desc')), 'Prueba E2E');
    await tapOn(t, find.byKey(const Key('transfer_continue')));

    await tapOn(t, find.byKey(const Key('transfer_confirm')));
    await pumpUntil(t, find.byKey(const Key('transfer_success')));

    await tapOn(t, find.byKey(const Key('transfer_done')));
    await pumpUntil(t, find.byKey(const Key('home_list')));
    // La notificación de la transferencia llega a la bandeja.
    await tapOn(t, find.text('Avisos'));
    await pumpUntil(t, find.text('Transferencia enviada'));
  });

  testWidgets('E2E onboarding: abrir cuenta con cédula → OTP → cuenta con bono de bienvenida', (t) async {
    await freshStart(t);
    final r = Random();
    await tapOn(t, find.byKey(const Key('welcome_register')));

    // Paso 1: identidad
    await fill(t, find.byKey(const Key('reg_cedula')), _validCedula(r));
    await fill(t, find.widgetWithText(TextFormField, 'Nombres'), 'Lucía');
    await fill(t, find.widgetWithText(TextFormField, 'Apellidos'), 'Pérez');
    await tapOn(t, find.text('Fecha de nacimiento'));
    await pumpUntil(t, find.byType(DatePickerDialog));
    // El último botón del diálogo es "Aceptar" (independiente del idioma).
    await t.tap(find.descendant(of: find.byType(DatePickerDialog), matching: find.byType(TextButton)).last);
    await t.pump(const Duration(milliseconds: 500));
    await tapOn(t, find.byKey(const Key('register_continue')));

    // Paso 2: contacto
    await fill(t, find.widgetWithText(TextFormField, 'Correo electrónico'), 'e2e${r.nextInt(1 << 30)}@kinti.ec');
    await fill(t, find.widgetWithText(TextFormField, 'Celular'), '09${r.nextInt(89999999) + 10000000}');
    await tapOn(t, find.byKey(const Key('register_continue')));

    // Paso 3: seguridad
    await fill(t, find.widgetWithText(TextFormField, 'Crea tu contraseña'), 'Segura2026');
    await tapOn(t, find.byType(Checkbox));
    expect(t.widget<Checkbox>(find.byType(Checkbox)).value, isTrue, reason: 'Debe quedar aceptado el término');
    await tapOn(t, find.byKey(const Key('register_continue')));

    // OTP (modo demo: el código se muestra en pantalla)
    await pumpUntil(t, find.byKey(const Key('otp_dev_hint')));
    await tapOn(t, find.text('Usar'));
    await tapOn(t, find.text('Verificar'));
    await pumpUntil(t, find.textContaining('Lucía'));
    await pumpUntil(t, find.textContaining(r'$10,00'));
  });
}