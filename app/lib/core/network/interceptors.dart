import 'dart:math';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../observability/telemetry.dart';
import '../storage/token_store.dart';
import 'network_health.dart';

const _uuid = Uuid();

/// Correlación extremo a extremo: el mismo X-Request-Id aparece en la app, Sentry y los logs del BFF.
class RequestIdInterceptor extends Interceptor {
  RequestIdInterceptor({required this.appVersion, required this.platform});
  final String appVersion;
  final String platform;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers.putIfAbsent('X-Request-Id', () => _uuid.v4());
    options.headers['X-Client'] = 'kinti-app/$appVersion ($platform)';
    options.extra['startedAt'] = DateTime.now().millisecondsSinceEpoch;
    handler.next(options);
  }
}

/// Adjunta el access token y renueva la sesión ante un 401 de forma serializada
/// (QueuedInterceptor): N requests concurrentes con token vencido → un solo refresh.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({required this.tokens, required this.refreshDio, required this.onSessionExpired});

  final TokenStore tokens;

  /// Dio sin interceptores: evita recursión y el deadlock clásico del QueuedInterceptor.
  final Dio refreshDio;
  final void Function() onSessionExpired;

  static const skipAuth = 'skipAuth';

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.extra[skipAuth] != true) {
      final t = await tokens.read();
      if (t != null) options.headers['Authorization'] = 'Bearer ${t.accessToken}';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final opts = err.requestOptions;
    if (err.response?.statusCode != 401 || opts.extra[skipAuth] == true || opts.extra['authRetried'] == true) {
      return handler.next(err);
    }
    final current = await tokens.read();
    if (current == null) {
      onSessionExpired();
      return handler.next(err);
    }
    // Si otra request ya refrescó mientras esta esperaba en cola, reintenta con el token nuevo.
    final sentWith = opts.headers['Authorization']?.toString();
    var fresh = current;
    if (sentWith == 'Bearer ${current.accessToken}') {
      try {
        final res = await refreshDio.post<Map<String, dynamic>>(
          '/v1/auth/refresh',
          data: {'refreshToken': current.refreshToken},
        );
        final data = res.data!;
        fresh = AuthTokens(accessToken: data['accessToken'] as String, refreshToken: data['refreshToken'] as String);
        await tokens.save(fresh);
      } on DioException catch (e) {
        if (e.response?.statusCode == 401) {
          await tokens.clear();
          onSessionExpired();
        }
        return handler.next(err);
      }
    }
    try {
      // Copia de la petición: la original no se modifica (historial y telemetría siguen siendo fieles).
      final retryOpts = opts.copyWith(
        headers: {...opts.headers, 'Authorization': 'Bearer ${fresh.accessToken}'},
        extra: {...opts.extra, 'authRetried': true},
      );
      final retried = await refreshDio.fetch<dynamic>(retryOpts);
      handler.resolve(retried);
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}

/// Reintentos con backoff exponencial + jitter, solo cuando es seguro:
/// métodos idempotentes (GET/PUT/DELETE) o POST con Idempotency-Key.
class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    required this.dio,
    this.maxRetries = 3,
    this.baseDelay = const Duration(milliseconds: 400),
    this.maxDelay = const Duration(seconds: 5),
    Random? random,
    Future<void> Function(Duration)? sleep,
    this.telemetry,
  }) : _random = random ?? Random(),
       _sleep = sleep ?? Future<void>.delayed;

  final Dio dio;
  final int maxRetries;
  final Duration baseDelay;
  final Duration maxDelay;
  final Random _random;
  final Future<void> Function(Duration) _sleep;
  final Telemetry? telemetry;

  static const attemptKey = 'retryAttempt';
  static const noRetry = 'noRetry';

  bool _isSafe(RequestOptions o) {
    final m = o.method.toUpperCase();
    return m == 'GET' || m == 'PUT' || m == 'DELETE' || m == 'HEAD' || o.headers.containsKey('Idempotency-Key');
  }

  bool shouldRetry(DioException e) {
    if (e.requestOptions.extra[noRetry] == true || !_isSafe(e.requestOptions)) return false;
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        final s = e.response?.statusCode ?? 0;
        return s == 502 || s == 503 || s == 504 || s == 429;
      default:
        return false;
    }
  }

  Duration delayFor(int attempt, {int? retryAfterSec}) {
    if (retryAfterSec != null) {
      final ra = Duration(seconds: retryAfterSec);
      return ra < maxDelay ? ra : maxDelay;
    }
    final exp = baseDelay.inMilliseconds * pow(2, attempt).toInt();
    final jitter = _random.nextInt(baseDelay.inMilliseconds);
    return Duration(milliseconds: min(exp + jitter, maxDelay.inMilliseconds));
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final attempt = (err.requestOptions.extra[attemptKey] as int?) ?? 0;
    if (attempt >= maxRetries || !shouldRetry(err)) return handler.next(err);
    final retryAfter = int.tryParse(err.response?.headers.value('retry-after') ?? '');
    final wait = delayFor(attempt, retryAfterSec: retryAfter);
    telemetry?.breadcrumb(
      'retry ${err.requestOptions.method} ${err.requestOptions.path} #${attempt + 1} in ${wait.inMilliseconds}ms',
      category: 'http',
    );
    await _sleep(wait);
    final opts = err.requestOptions..extra[attemptKey] = attempt + 1;
    try {
      handler.resolve(await dio.fetch<dynamic>(opts));
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}

/// Mide latencias, alimenta NetworkHealth y reporta errores con su requestId.
class TelemetryInterceptor extends Interceptor {
  TelemetryInterceptor(this.telemetry, this.health);
  final Telemetry telemetry;
  final NetworkHealth health;

  int _elapsed(RequestOptions o) => DateTime.now().millisecondsSinceEpoch - ((o.extra['startedAt'] as int?) ?? 0);

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    final o = response.requestOptions;
    final ms = _elapsed(o);
    health.onSuccess(o.headers['X-Request-Id']?.toString());
    telemetry.metric('http_client_duration_ms', ms.toDouble(), {'path': o.path, 'status': response.statusCode});
    if (ms > 2500) telemetry.event('slow_request', {'path': o.path, 'ms': ms});
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final o = err.requestOptions;
    final rid = o.headers['X-Request-Id']?.toString();
    final status = err.response?.statusCode;
    final transient = status == null || status >= 500 || status == 429;
    if (transient) health.onTransientFailure(rid);
    telemetry.breadcrumb(
      '${o.method} ${o.path} -> ${status ?? err.type.name} (${_elapsed(o)}ms) rid=$rid',
      category: 'http',
    );
    if (status != null && status >= 500) {
      telemetry.recordError(err, err.stackTrace, context: {'path': o.path, 'status': status, 'requestId': rid});
    }
    handler.next(err);
  }
}
