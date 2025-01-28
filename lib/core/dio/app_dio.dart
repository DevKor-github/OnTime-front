import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/constants/environment_variable.dart';
import 'package:on_time_front/core/dio/interceptors/logger_interceptor.dart';

@Injectable(as: Dio)
class AppDio with DioMixin implements Dio {
  AppDio() {
    httpClientAdapter = IOHttpClientAdapter();
    options = BaseOptions(
        baseUrl: EnvironmentVariable.restApiUrl,
        connectTimeout: const Duration(milliseconds: 30000),
        receiveTimeout: const Duration(milliseconds: 30000),
        sendTimeout: const Duration(milliseconds: 30000),
        receiveDataWhenStatusError: true,
        followRedirects: false,
        headers: {
          "Accept": "application/json",
          "Authorization": EnvironmentVariable.restAuthToken
        });

    interceptors.addAll([LoggerInterceptor()]);
  }
}
