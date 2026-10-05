import 'package:flutter_test/flutter_test.dart';
import 'package:kinti/features/microapps/presentation/microapp_bridge.dart';
import 'package:kinti/sdui/fallback_home.dart';
import 'package:kinti/sdui/sdui_models.dart';

void main() {
  group('SduiScreen', () {
    test('descarta secciones mal formadas sin invalidar la pantalla', () {
      final s = SduiScreen.fromJson({
        'schemaVersion': 1,
        'sections': [
          {
            'id': 'a',
            'type': 'banner',
            'props': {'title': 'Hola'},
          },
          {'type': 'sin_id'},
          'basura',
          {'id': 'b', 'type': 'greeting'},
        ],
        'meta': {
          'segment': 'joven',
          'reasons': ['Cliente joven'],
        },
      });
      expect(s.sections.map((e) => e.id), ['a', 'b']);
      expect(s.sections.first.str('title'), 'Hola');
      expect(s.sections.last.data, isEmpty);
      expect(s.reasons, ['Cliente joven']);
    });

    test('rechaza esquemas más nuevos que la app (se usará caché o fallback)', () {
      expect(() => SduiScreen.fromJson({'schemaVersion': 99, 'sections': []}), throwsFormatException);
      expect(() => SduiScreen.fromJson('no es json'), throwsFormatException);
    });

    test('la experiencia embebida es válida', () {
      final s = SduiScreen.fromJson(kFallbackHome, isFallback: true);
      expect(s.isFallback, isTrue);
      expect(s.sections, isNotEmpty);
    });
  });

  group('MicroappBridge (contrato v1)', () {
    final bridge = MicroappBridge(allowedNavigation: ['/transfer', '/assistant']);

    test('acepta mensajes válidos', () {
      expect(bridge.parse('{"v":1,"type":"ready"}'), isA<BridgeReady>());
      expect(bridge.parse('{"v":1,"type":"navigate","route":"/assistant"}'), isA<BridgeNavigate>());
      expect(bridge.parse('{"v":1,"type":"track","event":"microapp_mode_ahorro"}'), isA<BridgeTrack>());
    });

    test('rechaza rutas no autorizadas, versiones desconocidas y basura', () {
      expect(bridge.parse('{"v":1,"type":"navigate","route":"/settings"}'), isA<BridgeRejected>());
      expect(bridge.parse('{"v":2,"type":"ready"}'), isA<BridgeRejected>());
      expect(bridge.parse('<script>'), isA<BridgeRejected>());
      expect(bridge.parse('{"v":1,"type":"track","event":"login_success"}'), isA<BridgeRejected>());
    });

    test('el mensaje de sesión sigue el contrato', () {
      final msg = MicroappBridge.sessionMessage(token: 't', apiBase: 'http://x', context: {'firstName': 'Ana'});
      expect(msg, contains('"type":"session"'));
      expect(msg, contains('"v":1'));
    });
  });
}
