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
        headers: {
          "Accept": "application/json",
          "Authorization":
              "Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJBY2Nlc3NUb2tlbiIsImV4cCI6MTczMjcwMDQ5NywiZW1haWwiOiJ1c2VyQGV4YW1wbGUuY29tIiwidXNlcklkIjoxfQ.9LtGN1omJ2LkEnFUXT4pP52BE7dOyubX25VGQkIxRY6PxCxO74fiYsUosfo_XDmI5nf4cNuNGlqYVwNSK1qWTA"
        });

    interceptors.addAll([LoggerInterceptor()]);
  }
}
