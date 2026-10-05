import 'package:flutter_test/flutter_test.dart';
import 'package:kinti/app/deep_links.dart';
import 'package:kinti/core/utils/formatters.dart';

void main() {
  test('Money: formato, signo y parseo sin errores de coma flotante', () {
    expect(Money.format(123456789), r'$1.234.567,89');
    expect(Money.format(-1250), r'-$12,50');
    expect(Money.format(500, signed: true), r'+$5,00');
    expect(Money.parseToCents('12,5'), 1250);
    expect(Money.parseToCents('0.10'), 10);
    expect(Money.parseToCents('1.234'), isNull);
    expect(Money.parseToCents('abc'), isNull);
    expect(Money.toApi(1205), '12.05');
    expect(Money.spoken(1250), '12 dólares con 50 centavos');
  });

  test('Cédula ecuatoriana', () {
    expect(Cedula.isValid('1710034065'), isTrue);
    expect(Cedula.isValid('0604123455'), isTrue);
    expect(Cedula.isValid('1710034066'), isFalse);
    expect(Cedula.isValid('2510034065'), isFalse);
    expect(Cedula.isValid('171003406'), isFalse);
  });

  test('Fechas relativas', () {
    final now = DateTime(2026, 10, 3, 12);
    expect(Dates.dayHeader(DateTime(2026, 10, 3, 8), now: now), 'Hoy');
    expect(Dates.dayHeader(DateTime(2026, 10, 2, 8), now: now), 'Ayer');
    expect(Dates.ago(now.subtract(const Duration(minutes: 5)), now: now), 'hace 5 min');
  });

  test('DeepLinks: lista blanca de destinos', () {
    expect(DeepLinks.resolve('/transfer'), '/transfer');
    expect(DeepLinks.resolve('/accounts?category=restaurantes'), '/accounts?category=restaurantes');
    expect(DeepLinks.resolve('microapp://simulador-credito?mode=ahorro'), '/microapp/simulador-credito?mode=ahorro');
    expect(DeepLinks.resolve('https://phishing.example/login'), isNull);
    expect(DeepLinks.resolve('/admin/secret'), isNull);
    expect(DeepLinks.resolve('microapp://../../etc'), isNull);
  });
}
