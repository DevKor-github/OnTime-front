import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:on_time_front/core/dio/interceptors/logger_interceptor.dart';

abstract class AppDio {
  AppDio._internal();

  static Dio? _instance;

  static Dio get instance => _instance ??= _AppDio();
}

class _AppDio with DioMixin implements Dio {
  _AppDio() {
    httpClientAdapter = IOHttpClientAdapter();
    options = BaseOptions(
      baseUrl: '',
      connectTimeout: const Duration(milliseconds: 30000),
      receiveTimeout: const Duration(milliseconds: 30000),
      sendTimeout: const Duration(milliseconds: 30000),
      receiveDataWhenStatusError: true,
    );

    interceptors.addAll([LoggerInterceptor()]);
  }
}
