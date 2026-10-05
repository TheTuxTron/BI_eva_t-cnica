import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kinti/core/observability/telemetry.dart';
import 'package:kinti/core/storage/token_store.dart';

class ScriptedAdapter implements HttpClientAdapter {
  ScriptedAdapter(this.script);

  /// Cada elemento es un [ResponseBody] o un [DioExceptionType] a lanzar.
  final List<Object> script;
  final List<RequestOptions> requests = [];

  /// Headers tal como se enviaron (foto en el momento del envío).
  final List<Map<String, dynamic>> sentHeaders = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    sentHeaders.add(Map<String, dynamic>.of(options.headers));
    if (script.isEmpty) throw StateError('Sin más respuestas guionadas para ${options.method} ${options.path}');
    final next = script.removeAt(0);
    if (next is DioExceptionType) throw DioException(requestOptions: options, type: next);
    return next as ResponseBody;
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(int status, Object body, {Map<String, List<String>> headers = const {}}) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        ...headers,
      },
    );

class FakeTelemetry implements Telemetry {
  final events = <String>[];
  final errors = <Object>[];
  @override
  void event(String name, [Map<String, Object?> props = const {}]) => events.add(name);
  @override
  void screen(String name) => events.add('screen:$name');
  @override
  void metric(String name, double value, [Map<String, Object?> tags = const {}]) {}
  @override
  void breadcrumb(String message, {String category = 'app'}) {}
  @override
  void recordError(Object error, StackTrace? stack, {bool fatal = false, Map<String, Object?> context = const {}}) => errors.add(error);
  @override
  void setUser(String? userId) {}
}

class MemoryTokenStore extends TokenStore {
  MemoryTokenStore([this.tokens]) : super(const FlutterSecureStorage());
  AuthTokens? tokens;
  bool cleared = false;
  @override
  Future<AuthTokens?> read() async => tokens;
  @override
  Future<void> save(AuthTokens t, {String? userId}) async => tokens = t;
  @override
  Future<String?> userId() async => 'usr_test';
  @override
  Future<void> clear() async {
    cleared = true;
    tokens = null;
  }
}
