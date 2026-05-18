import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/dio/interceptors/logger_interceptor.dart';

void main() {
  late Dio dio;
  late _LoggerAdapter adapter;

  setUp(() {
    adapter = _LoggerAdapter();
    dio = Dio(
      BaseOptions(
        baseUrl: 'https://example.com',
        receiveDataWhenStatusError: true,
      ),
    )..httpClientAdapter = adapter;
    dio.interceptors.add(LoggerInterceptor());
  });

  test('passes successful requests and responses through unchanged', () async {
    adapter.nextStatusCode = 200;

    final response = await dio.post<Map<String, dynamic>>(
      '/appointments',
      queryParameters: {'token': 'secret-token'},
      data: {'name': 'Design review'},
      options: Options(headers: {'Authorization': 'Bearer secret'}),
    );

    expect(response.statusCode, 200);
    expect(response.data, {'message': 'ok'});
    expect(adapter.requestedPaths, ['/appointments']);
    expect(adapter.requestedMethods, ['POST']);
  });

  test('passes Dio errors through to the caller', () async {
    adapter.nextStatusCode = 500;

    await expectLater(
      dio.get<Map<String, dynamic>>(
        '/broken',
        options: Options(headers: {'Authorization-refresh': 'refresh'}),
      ),
      throwsA(
        isA<DioException>().having(
          (error) => error.response?.statusCode,
          'statusCode',
          500,
        ),
      ),
    );

    expect(adapter.requestedPaths, ['/broken']);
    expect(adapter.requestedMethods, ['GET']);
  });
}

class _LoggerAdapter implements HttpClientAdapter {
  int nextStatusCode = 200;
  final requestedPaths = <String>[];
  final requestedMethods = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestedPaths.add(options.path);
    requestedMethods.add(options.method);
    return ResponseBody.fromString(
      '{"message":"ok"}',
      nextStatusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
