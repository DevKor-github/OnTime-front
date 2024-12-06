import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:on_time_front/core/dio/interceptors/logger_interceptor.dart';

class AppDio with DioMixin implements Dio {
  AppDio() {
    httpClientAdapter = IOHttpClientAdapter();
    options = BaseOptions(
        baseUrl: 'http://ejun.kro.kr:8888',
        connectTimeout: const Duration(milliseconds: 30000),
        receiveTimeout: const Duration(milliseconds: 30000),
        sendTimeout: const Duration(milliseconds: 30000),
        receiveDataWhenStatusError: true,
        followRedirects: false,
        headers: {"Accept": "application/json", "Authorization": ""});

    interceptors.addAll([LoggerInterceptor()]);
  }
}
