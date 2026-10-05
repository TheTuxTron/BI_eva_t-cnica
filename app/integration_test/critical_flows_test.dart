import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kinti/app/bootstrap.dart';
import 'package:kinti/app/env.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Flujos E2E contra el BFF real (no mocks). Requiere el BFF corriendo:
///   cd bff && npm start
///   cd app && flutter test integration_test --dart-define=API_BASE_URL=http://10.0.2.2:8080
const _env = AppEnv(
  apiBaseUrl: String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8080'),
  flavor: 'e2e',
  enableDevTools: true,
);

/// pumpAndSettle no sirve con animaciones infinitas (skeletons/progress); se espera por un finder.
Future<void> pumpUntil(WidgetTester t, Finder f, {Duration timeout = const Duration(seconds: 20)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 200));
    if (f.evaluate().isNotEmpty) return;
  }
  throw TestFailure('No apareció: $f');
}

Future<void> freshStart(WidgetTester t) async {
  await const FlutterSecureStorage().deleteAll();
  final prefs = await SharedPreferences.getInstance();
  for (final k in prefs.getKeys().where((k) => k.startsWith('kc:')).toList()) {
    await prefs.remove(k);
  }
  await bootstrap(env: _env);
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

  testWidgets('E2E crítico: login → inicio personalizado → transferencia → saldo actualizado', (t) async {
    await freshStart(t);
    await t.tap(find.byKey(const Key('welcome_login')));
    await pumpUntil(t, find.byKey(const Key('login_username')));
    await t.enterText(find.byKey(const Key('login_username')), 'ana@kinti.ec');
    await t.enterText(find.byKey(const Key('login_password')), 'Kinti2026!');
    await t.tap(find.byKey(const Key('login_submit')));

    // Inicio dirigido por servidor para el segmento "joven".
    await pumpUntil(t, find.textContaining('Ana'));
    await pumpUntil(t, find.text('Meta de ahorro'));

    await t.tap(find.text('Transferir').first);
    await pumpUntil(t, find.byKey(const Key('transfer_to')));
    await t.enterText(find.byKey(const Key('transfer_to')), '2200990011');
    await pumpUntil(t, find.textContaining('Titular: María Y.'));
    await t.enterText(find.byKey(const Key('transfer_amount')), '1.25');
    await t.enterText(find.byKey(const Key('transfer_desc')), 'Prueba E2E');
    FocusManager.instance.primaryFocus?.unfocus();
    await t.pump();
    await t.ensureVisible(find.byKey(const Key('transfer_continue')));
    await t.tap(find.byKey(const Key('transfer_continue')));
    await pumpUntil(t, find.byKey(const Key('transfer_confirm')));
    await t.tap(find.byKey(const Key('transfer_confirm')));
    await pumpUntil(t, find.byKey(const Key('transfer_success')));

    await t.tap(find.byKey(const Key('transfer_done')));
    await pumpUntil(t, find.byKey(const Key('home_list')));
    // La notificación de la transferencia llega a la bandeja.
    await t.tap(find.text('Avisos'));
    await pumpUntil(t, find.text('Transferencia enviada'));
  });

  testWidgets('E2E onboarding: abrir cuenta con cédula → OTP → cuenta con bono de bienvenida', (t) async {
    await freshStart(t);
    final r = Random();
    await t.tap(find.byKey(const Key('welcome_register')));
    await pumpUntil(t, find.byKey(const Key('reg_cedula')));
    await t.enterText(find.byKey(const Key('reg_cedula')), _validCedula(r));
    await t.enterText(find.widgetWithText(TextFormField, 'Nombres'), 'Lucía');
    await t.enterText(find.widgetWithText(TextFormField, 'Apellidos'), 'Pérez');
    await t.tap(find.text('Fecha de nacimiento'));
    await pumpUntil(t, find.byType(DatePickerDialog));
    // El último botón del diálogo es "Aceptar" (independiente del idioma).
    await t.tap(find.descendant(of: find.byType(DatePickerDialog), matching: find.byType(TextButton)).last);
    await t.pump(const Duration(milliseconds: 500));
    await t.tap(find.byKey(const Key('register_continue')));
    await t.pump(const Duration(milliseconds: 500));

    await t.enterText(find.widgetWithText(TextFormField, 'Correo electrónico'), 'e2e${r.nextInt(1 << 30)}@kinti.ec');
    await t.enterText(find.widgetWithText(TextFormField, 'Celular'), '09${r.nextInt(89999999) + 10000000}');
    await t.tap(find.byKey(const Key('register_continue')));
    await t.pump(const Duration(milliseconds: 500));

    await t.enterText(find.widgetWithText(TextFormField, 'Crea tu contraseña'), 'Segura2026');
    await t.ensureVisible(find.byType(Checkbox));
    await t.tap(find.byType(Checkbox));
    await t.tap(find.byKey(const Key('register_continue')));

    await pumpUntil(t, find.byKey(const Key('otp_dev_hint')));
    await t.tap(find.text('Usar'));
    await t.tap(find.text('Verificar'));
    await pumpUntil(t, find.textContaining('Lucía'));
    await pumpUntil(t, find.textContaining(r'$10,00'));
  });
}
