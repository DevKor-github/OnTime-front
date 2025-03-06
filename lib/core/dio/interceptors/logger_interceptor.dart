import 'dart:developer';

import 'package:dio/dio.dart';

class LoggerInterceptor implements Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    log('❌ Dio Error!');
    log('❌ Url: ${err.requestOptions.uri}');
    log('❌ Data: ${err.requestOptions.data}');
    log('❌ ${err.stackTrace}');
    log('❌ Response Error: ${err.response?.data}');
    log('❌ Response Message: ${err.message}');
    return handler.next(err);
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    log('🌍 Sending network request: ${options.baseUrl}${options.path}');
    log('🌍 Header: ${options.headers}');
    log('🌍 Query: ${options.queryParameters}');
    log('🌍 Data: ${options.data}');

    return handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    log('⬅️ Received network response');
    if (response.data is Map && response.data['status'] != null) {
      log('${'✅ ${response.data['status']} ✅'} ${response.requestOptions.baseUrl}${response.requestOptions.path}');
    } else {
      log('${'✅ ${response.statusCode} ✅'} ${response.requestOptions.baseUrl}${response.requestOptions.path}');
    }
    log('Query params: ${response.requestOptions.queryParameters}');
    log('Response Data: ${response.data}');
    log('-------------------------');
    return handler.next(response);
  }
}
