import 'package:dio/dio.dart';
import 'package:on_time_front/core/logging/app_logger.dart';

class LoggerInterceptor implements Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    AppLogger.debug(
      'Dio error '
      '${err.requestOptions.method} '
      '${AppLogger.redactUri(err.requestOptions.uri)} '
      'status=${err.response?.statusCode} '
      'type=${err.type} '
      'message=${err.message}',
    );
    AppLogger.debug(
      'Dio error headers=${AppLogger.redactValue(err.requestOptions.headers)}',
    );
    return handler.next(err);
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    AppLogger.debug(
      'Dio request ${options.method} ${AppLogger.redactUri(options.uri)}',
    );
    AppLogger.debug('Dio headers=${AppLogger.redactValue(options.headers)}');
    AppLogger.debug(
      'Dio query=${AppLogger.redactValue(options.queryParameters)}',
    );
    if (options.data != null) {
      AppLogger.debug(
        'Dio request body=${AppLogger.omitted} type=${options.data.runtimeType}',
      );
    }

    return handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    AppLogger.debug(
      'Dio response ${response.requestOptions.method} '
      '${AppLogger.redactUri(response.requestOptions.uri)} '
      'status=${response.statusCode}',
    );
    AppLogger.debug(
      'Dio query=${AppLogger.redactValue(response.requestOptions.queryParameters)}',
    );
    if (response.data != null) {
      AppLogger.debug(
        'Dio response body=${AppLogger.omitted} type=${response.data.runtimeType}',
      );
    }
    return handler.next(response);
  }
}
