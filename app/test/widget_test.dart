import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinti/design_system/widgets.dart';

void main() {
  testWidgets('AmountText: formato visible y lectura accesible', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: AmountText(123450))));
    expect(find.text(r'$1.234,50'), findsOneWidget);
    expect(find.bySemanticsLabel('1234 dólares con 50 centavos'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('AmountText oculto no expone el saldo ni a lectores de pantalla', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: AmountText(123450, hidden: true))));
    expect(find.textContaining('1.234'), findsNothing);
    expect(find.bySemanticsLabel('Saldo oculto'), findsOneWidget);
    handle.dispose();
  });
}
