import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinti/features/accounts/data/accounts_repository.dart';
import 'package:kinti/features/accounts/presentation/account_widgets.dart';

const _account = Account(
  id: 'acc_1',
  type: 'savings',
  number: '2200112233',
  maskedNumber: '****2233',
  alias: 'Ahorro principal',
  balanceCents: 88100,
);

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  test('agrupa el número de 4 en 4', () {
    expect(AccountNumberText.group('2200112233'), '2200 1122 33');
  });

  testWidgets('muestra el número completo con botón de copiar', (tester) async {
    await tester.pumpWidget(_host(const AccountNumberText(account: _account)));
    expect(find.text('Ahorros · 2200 1122 33'), findsOneWidget);
    expect(find.byTooltip('Copiar número de cuenta'), findsOneWidget);
  });

  testWidgets('en modo privacidad lo enmascara y no permite copiar', (tester) async {
    await tester.pumpWidget(_host(const AccountNumberText(account: _account, hidden: true)));
    expect(find.text('Ahorros · ****2233'), findsOneWidget);
    expect(find.textContaining('2200 1122'), findsNothing);
    expect(find.byTooltip('Copiar número de cuenta'), findsNothing);
  });

  testWidgets('copia el número sin espacios y lo confirma', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(_host(const AccountNumberText(account: _account)));
    await tester.tap(find.byTooltip('Copiar número de cuenta'));
    await tester.pump();
    expect(copied, '2200112233');
    expect(find.text('Número de cuenta copiado'), findsOneWidget);
  });
}
