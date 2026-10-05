import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinti/sdui/components/common_components.dart';
import 'package:kinti/sdui/sdui_models.dart';
import 'package:kinti/sdui/sdui_registry.dart';
import 'package:kinti/sdui/sdui_renderer.dart';

import '../helpers/fakes.dart';

void main() {
  late SduiRegistry registry;
  late FakeTelemetry telemetry;

  setUp(() {
    registry = SduiRegistry();
    registerCommonComponents(registry);
    registry.register('explota', (_, __) => throw StateError('bug en componente'));
    telemetry = FakeTelemetry();
  });

  Future<void> render(WidgetTester tester, List<SduiSection> sections) => tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: SduiRenderer(sections: sections, registry: registry, telemetry: telemetry))),
      ));

  testWidgets('renderiza componentes en el orden que decide el servidor', (tester) async {
    await render(tester, const [
      SduiSection(id: 'g', type: 'greeting', data: {'title': 'Buenos días, Ana', 'subtitle': 'Cada dólar cuenta.'}),
      SduiSection(id: 'b', type: 'banner', data: {'title': 'Tu primera meta', 'body': 'Ahorra cada quincena', 'cta': {'label': 'Simular', 'deeplink': '/assistant'}}),
      SduiSection(id: 'q', type: 'quick_actions', data: {
        'actions': [
          {'id': 'transfer', 'label': 'Transferir', 'icon': 'swap_horiz', 'deeplink': '/transfer'},
          {'id': 'savings', 'label': 'Meta de ahorro', 'icon': 'savings', 'deeplink': '/x'},
        ],
      }),
    ]);
    expect(find.text('Buenos días, Ana'), findsOneWidget);
    expect(find.text('Tu primera meta'), findsOneWidget);
    expect(find.text('Simular'), findsOneWidget);
    expect(find.text('Transferir'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Buenos días, Ana')).dy, lessThan(tester.getTopLeft(find.text('Tu primera meta')).dy));
  });

  testWidgets('omite componentes desconocidos y aísla los que fallan', (tester) async {
    await render(tester, const [
      SduiSection(id: 'x', type: 'holograma_3d'),
      SduiSection(id: 'e', type: 'explota'),
      SduiSection(id: 'g', type: 'greeting', data: {'title': 'Sigo aquí'}),
    ]);
    expect(find.text('Sigo aquí'), findsOneWidget);
    expect(telemetry.events, contains('sdui_unknown_component'));
    expect(telemetry.errors, hasLength(1));
  });

  testWidgets('props con tipos inesperados no rompen el render', (tester) async {
    await render(tester, const [
      SduiSection(id: 'b', type: 'banner', data: {'title': 42, 'cta': 'no-es-mapa'}),
      SduiSection(id: 'q', type: 'quick_actions', data: {'actions': 'no-es-lista'}),
    ]);
    expect(tester.takeException(), isNull);
  });
}
