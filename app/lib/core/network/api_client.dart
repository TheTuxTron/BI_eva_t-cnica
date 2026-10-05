import 'package:dio/dio.dart';

import 'failures.dart';

/// Cliente HTTP delgado: traduce errores a [AppFailure] y expone solo JSON.
class ApiClient {
  ApiClient(this.dio);
  final Dio dio;

  Future<T> get<T>(String path, {Map<String, dynamic>? query, Options? options}) =>
      _wrap(() => dio.get<T>(path, queryParameters: query, options: options));

  Future<T> post<T>(String path, {Object? body, Map<String, String>? headers, Options? options}) =>
      _wrap(() => dio.post<T>(path, data: body, options: (options ?? Options()).copyWith(headers: headers)));

  Future<T> put<T>(String path, {Object? body}) => _wrap(() => dio.put<T>(path, data: body));

  Future<T> delete<T>(String path) => _wrap(() => dio.delete<T>(path));

  Future<T> _wrap<T>(Future<Response<T>> Function() call) async {
    try {
      final res = await call();
      return res.data as T;
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }
}

typedef Json = Map<String, dynamic>;
