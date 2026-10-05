import 'package:dio/dio.dart';

/// Errores de dominio. La UI nunca ve DioException: decide qué mostrar según el tipo.
sealed class AppFailure implements Exception {
  const AppFailure(this.message, {this.requestId});
  final String message;
  final String? requestId;

  /// Si vale la pena reintentar automáticamente / ofrecer "Reintentar".
  bool get isTransient => false;

  @override
  String toString() => '$runtimeType($message, requestId: $requestId)';

  static AppFailure from(Object error) {
    if (error is AppFailure) return error;
    if (error is DioException) return fromDio(error);
    return UnknownFailure(error.toString());
  }

  static AppFailure fromDio(DioException e) {
    final requestId = e.requestOptions.headers['X-Request-Id']?.toString();
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return TimeoutFailure(requestId: requestId);
      case DioExceptionType.connectionError:
        return NetworkFailure(requestId: requestId, detail: e.message ?? e.error?.toString());
      case DioExceptionType.cancel:
        return const CancelledFailure();
      case DioExceptionType.badResponse:
        return _fromResponse(e.response, requestId);
      case DioExceptionType.badCertificate:
        return SecurityFailure(requestId: requestId);
      default:
        // Incluye `unknown` y tipos agregados en versiones nuevas de Dio (p. ej. transformTimeout).
        if (e.error is AppFailure) return e.error! as AppFailure;
        if (e.type.name.toLowerCase().contains('timeout')) return TimeoutFailure(requestId: requestId);
        return NetworkFailure(requestId: requestId, detail: e.message ?? e.error?.toString());
    }
  }

  static AppFailure _fromResponse(Response<dynamic>? res, String? requestId) {
    final status = res?.statusCode ?? 0;
    final data = res?.data;
    final err = data is Map && data['error'] is Map ? data['error'] as Map : const {};
    final code = err['code']?.toString() ?? 'HTTP_$status';
    final message = err['message']?.toString() ?? 'Ocurrió un error inesperado';
    final rid = err['requestId']?.toString() ?? requestId;
    if (status == 401) return UnauthorizedFailure(message, requestId: rid);
    if (status == 503 || status == 502 || status == 504) {
      final retryAfter = int.tryParse(res?.headers.value('retry-after') ?? '');
      return ServiceUnavailableFailure(message, code: code, retryAfter: retryAfter, requestId: rid);
    }
    if (status >= 500) return ServerFailure(message, code: code, requestId: rid);
    final fields = <String, String>{};
    final details = err['details'];
    if (details is List) {
      for (final d in details.whereType<Map<dynamic, dynamic>>()) {
        fields[d['field'].toString()] = d['message'].toString();
      }
    }
    return BusinessFailure(message, code: code, fieldErrors: fields, requestId: rid);
  }
}

class NetworkFailure extends AppFailure {
  const NetworkFailure({String? requestId, this.detail})
    : super('No pudimos conectarnos. Revisa tu conexión.', requestId: requestId);

  /// Causa técnica (solo se muestra en builds de debug para diagnosticar).
  final String? detail;
  @override
  bool get isTransient => true;
}

class TimeoutFailure extends AppFailure {
  const TimeoutFailure({String? requestId})
    : super('El servicio está tardando más de lo normal.', requestId: requestId);
  @override
  bool get isTransient => true;
}

class ServiceUnavailableFailure extends AppFailure {
  const ServiceUnavailableFailure(super.message, {required this.code, this.retryAfter, super.requestId});
  final String code;
  final int? retryAfter;
  @override
  bool get isTransient => true;
}

class ServerFailure extends AppFailure {
  const ServerFailure(super.message, {required this.code, super.requestId});
  final String code;
  @override
  bool get isTransient => true;
}

class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure(super.message, {super.requestId});
}

class BusinessFailure extends AppFailure {
  const BusinessFailure(super.message, {required this.code, this.fieldErrors = const {}, super.requestId});
  final String code;
  final Map<String, String> fieldErrors;
}

class SecurityFailure extends AppFailure {
  const SecurityFailure({String? requestId}) : super('Conexión no segura bloqueada.', requestId: requestId);
}

class CancelledFailure extends AppFailure {
  const CancelledFailure() : super('Operación cancelada');
}

class UnknownFailure extends AppFailure {
  const UnknownFailure(super.message);
}
