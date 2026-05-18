import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/core/dio/app_dio.dart';
import 'package:on_time_front/core/dio/interceptors/logger_interceptor.dart';
import 'package:on_time_front/core/dio/interceptors/token_interceptor.dart';
import 'package:on_time_front/core/dio/transformers/logging_transformer.dart';
import 'package:on_time_front/data/data_sources/token_local_data_source.dart';
import 'package:on_time_front/domain/entities/token_entity.dart';

void main() {
  tearDown(() async {
    await getIt.reset();
  });

  test(
    'logging transformer preserves serialized request and response body',
    () async {
      final inner = _FakeTransformer();
      final transformer = LoggingTransformer(inner: inner);
      final options = RequestOptions(path: '/test', method: 'POST');
      final responseBody = ResponseBody.fromString('{"ok":true}', 200);

      expect(await transformer.transformRequest(options), '{"name":"meeting"}');
      expect(await transformer.transformResponse(options, responseBody), {
        'ok': true,
      });
    },
  );

  test('AppDio configures JSON defaults, logging, and auth interceptors', () {
    getIt.registerSingleton<TokenLocalDataSource>(_FakeTokenLocalDataSource());

    final dio = AppDio();

    expect(dio.options.contentType, Headers.jsonContentType);
    expect(dio.options.receiveDataWhenStatusError, isTrue);
    expect(dio.options.followRedirects, isFalse);
    expect(dio.transformer, isA<LoggingTransformer>());
    expect(dio.interceptors.whereType<TokenInterceptor>(), hasLength(1));
    expect(dio.interceptors.whereType<LoggerInterceptor>(), hasLength(1));
  });
}

class _FakeTransformer implements Transformer {
  @override
  Future<String> transformRequest(RequestOptions options) async {
    return '{"name":"meeting"}';
  }

  @override
  Future<dynamic> transformResponse(
    RequestOptions options,
    ResponseBody responseBody,
  ) async {
    return {'ok': true};
  }
}

class _FakeTokenLocalDataSource implements TokenLocalDataSource {
  @override
  Future<void> storeTokens(TokenEntity token) async {}

  @override
  Future<void> storeAuthToken(String token) async {}

  @override
  Future<TokenEntity> getToken() async {
    return const TokenEntity(accessToken: 'access', refreshToken: 'refresh');
  }

  @override
  Future<void> deleteToken() async {}
}
