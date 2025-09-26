import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/constants/environment_variable.dart';
import 'package:on_time_front/core/dio/adapters/shared.dart';
import 'package:on_time_front/core/dio/interceptors/logger_interceptor.dart';
import 'package:on_time_front/core/dio/interceptors/token_interceptor.dart';
import 'package:on_time_front/core/dio/transformers/logging_transformer.dart';

@Injectable(as: Dio)
class AppDio with DioMixin implements Dio {
  AppDio() {
    httpClientAdapter = getAdapter();
    transformer = LoggingTransformer(inner: BackgroundTransformer());
    options = BaseOptions(
        contentType: Headers.jsonContentType,
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

    interceptors.addAll([TokenInterceptor(this), LoggerInterceptor()]);
  }
}
