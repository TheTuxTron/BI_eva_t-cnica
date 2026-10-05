import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinti/core/network/api_client.dart';
import 'package:kinti/core/network/failures.dart';
import 'package:kinti/core/network/interceptors.dart';
import 'package:kinti/core/storage/token_store.dart';

import '../helpers/fakes.dart';

Dio _dio(ScriptedAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter;
  dio.interceptors.add(RetryInterceptor(dio: dio, sleep: (_) async {}));
  return dio;
}

void main() {
  group('RetryInterceptor', () {
    test('reintenta GET ante 503 y termina con éxito', () async {
      final adapter = ScriptedAdapter([
        jsonBody(503, {}),
        jsonBody(503, {}),
        jsonBody(200, {'ok': true}),
      ]);
      final res = await _dio(adapter).get<Map<String, dynamic>>('/v1/accounts');
      expect(res.data!['ok'], true);
      expect(adapter.requests, hasLength(3));
    });

    test('NO reintenta un POST sin Idempotency-Key (podría duplicar la operación)', () async {
      final adapter = ScriptedAdapter([jsonBody(503, {})]);
      await expectLater(_dio(adapter).post<dynamic>('/v1/transfers'), throwsA(isA<DioException>()));
      expect(adapter.requests, hasLength(1));
    });

    test('sí reintenta un POST con Idempotency-Key, con la misma clave', () async {
      final adapter = ScriptedAdapter([
        DioExceptionType.connectionError,
        jsonBody(201, {'id': 't1'}),
      ]);
      await _dio(adapter).post<dynamic>('/v1/transfers', options: Options(headers: {'Idempotency-Key': 'abc-123-key'}));
      expect(adapter.requests, hasLength(2));
      expect(adapter.requests.map((r) => r.headers['Idempotency-Key']).toSet(), {'abc-123-key'});
    });

    test('se rinde tras el máximo de reintentos', () async {
      final adapter = ScriptedAdapter(List.generate(4, (_) => jsonBody(503, {})));
      await expectLater(_dio(adapter).get<dynamic>('/x'), throwsA(isA<DioException>()));
      expect(adapter.requests, hasLength(4)); // 1 intento + 3 reintentos
    });

    test('no reintenta errores de negocio (4xx)', () async {
      final adapter = ScriptedAdapter([jsonBody(422, {})]);
      await expectLater(_dio(adapter).get<dynamic>('/x'), throwsA(isA<DioException>()));
      expect(adapter.requests, hasLength(1));
    });

    test('backoff exponencial acotado y respeta Retry-After', () {
      final r = RetryInterceptor(dio: Dio());
      expect(r.delayFor(0).inMilliseconds, inInclusiveRange(400, 800));
      expect(r.delayFor(5).inMilliseconds, lessThanOrEqualTo(5000));
      expect(r.delayFor(0, retryAfterSec: 2), const Duration(seconds: 2));
      expect(r.delayFor(0, retryAfterSec: 60), const Duration(seconds: 5));
    });
  });

  group('AuthInterceptor', () {
    test('ante 401 refresca el token una vez y repite la petición', () async {
      final tokens = MemoryTokenStore(const AuthTokens(accessToken: 'old', refreshToken: 'r1'));
      final main = ScriptedAdapter([
        jsonBody(401, {
          'error': {'code': 'UNAUTHORIZED', 'message': 'Token expirado'},
        }),
      ]);
      final refresh = ScriptedAdapter([
        jsonBody(200, {'accessToken': 'new', 'refreshToken': 'r2'}),
        jsonBody(200, {'items': []}),
      ]);
      final refreshDio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = refresh;
      var expired = false;
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = main;
      dio.interceptors.add(
        AuthInterceptor(tokens: tokens, refreshDio: refreshDio, onSessionExpired: () => expired = true),
      );

      final res = await dio.get<Map<String, dynamic>>('/v1/accounts');
      expect(res.statusCode, 200);
      expect(main.sentHeaders.single['Authorization'], 'Bearer old');
      expect(refresh.sentHeaders.last['Authorization'], 'Bearer new');
      expect(tokens.tokens!.refreshToken, 'r2');
      expect(expired, isFalse);
    });

    test('si el refresh es rechazado, cierra la sesión', () async {
      final tokens = MemoryTokenStore(const AuthTokens(accessToken: 'old', refreshToken: 'r1'));
      final refreshDio = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = ScriptedAdapter([jsonBody(401, {})]);
      var expired = false;
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = ScriptedAdapter([jsonBody(401, {})]);
      dio.interceptors.add(
        AuthInterceptor(tokens: tokens, refreshDio: refreshDio, onSessionExpired: () => expired = true),
      );

      await expectLater(ApiClient(dio).get<dynamic>('/v1/accounts'), throwsA(isA<UnauthorizedFailure>()));
      expect(expired, isTrue);
      expect(tokens.cleared, isTrue);
    });
  });

  group('AppFailure', () {
    test('traduce respuestas HTTP a fallas de dominio', () async {
      Future<AppFailure> failFor(Object script) async {
        final dio = Dio(BaseOptions(baseUrl: 'http://t'))..httpClientAdapter = ScriptedAdapter([script]);
        try {
          await ApiClient(dio).get<dynamic>('/x');
        } on AppFailure catch (f) {
          return f;
        }
        throw StateError('no falló');
      }

      expect(await failFor(DioExceptionType.connectionError), isA<NetworkFailure>());
      expect(await failFor(DioExceptionType.receiveTimeout), isA<TimeoutFailure>());
      final unavailable = await failFor(
        jsonBody(
          503,
          {
            'error': {'code': 'SERVICE_UNAVAILABLE', 'message': 'Caído'},
          },
          headers: {
            'retry-after': ['10'],
          },
        ),
      );
      expect(unavailable, isA<ServiceUnavailableFailure>().having((f) => f.retryAfter, 'retryAfter', 10));
      expect(unavailable.isTransient, isTrue);
      final business = await failFor(
        jsonBody(400, {
          'error': {
            'code': 'BAD_REQUEST',
            'message': 'Datos inválidos',
            'requestId': 'rid-1',
            'details': [
              {'field': 'cedula', 'message': 'Cédula inválida'},
            ],
          },
        }),
      );
      expect(business, isA<BusinessFailure>().having((f) => f.fieldErrors['cedula'], 'campo', 'Cédula inválida'));
      expect(business.requestId, 'rid-1');
      expect(business.isTransient, isFalse);
    });
  });
}
