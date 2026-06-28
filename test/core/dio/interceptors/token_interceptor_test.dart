import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/constants/endpoint.dart';
import 'package:on_time_front/core/dio/interceptors/token_interceptor.dart';
import 'package:on_time_front/core/dio/interceptors/token_session_invalidator.dart';
import 'package:on_time_front/data/data_sources/token_local_data_source.dart';
import 'package:on_time_front/domain/entities/token_entity.dart';

void main() {
  late Dio dio;
  late _FakeTokenLocalDataSource tokenLocalDataSource;
  late _FakeTokenSessionInvalidator sessionInvalidator;
  late _TokenRefreshAdapter adapter;

  setUp(() async {
    tokenLocalDataSource = _FakeTokenLocalDataSource();
    sessionInvalidator = _FakeTokenSessionInvalidator(tokenLocalDataSource);

    adapter = _TokenRefreshAdapter();
    dio = Dio(
      BaseOptions(
        baseUrl: 'https://example.com',
        receiveDataWhenStatusError: true,
      ),
    )..httpClientAdapter = adapter;
    dio.interceptors.add(
      TokenInterceptor(
        dio,
        tokenLocalDataSource: tokenLocalDataSource,
        sessionInvalidator: sessionInvalidator,
      ),
    );
  });

  test(
    'stores refreshed access and refresh tokens before retrying request',
    () async {
      final response = await dio.get<String>('/protected');

      expect(response.statusCode, 200);
      expect(
        tokenLocalDataSource.storedToken,
        const TokenEntity(
          accessToken: 'new-access-token',
          refreshToken: 'new-refresh-token',
        ),
      );
      expect(tokenLocalDataSource.storeTokensCallCount, 1);
      expect(adapter.refreshRequests, 1);
      expect(
        adapter.protectedAuthorizationHeaders,
        contains('Bearer new-access-token'),
      );
    },
  );

  test('retries concurrent queued requests after a single refresh', () async {
    final refreshCompleter = Completer<void>();
    adapter = _TokenRefreshAdapter(refreshCompleter: refreshCompleter);
    dio.httpClientAdapter = adapter;

    final firstRequest = dio.get<String>('/protected/one');
    await _flushMicrotasks();
    final secondRequest = dio.get<String>('/protected/two');
    await _flushMicrotasks();

    expect(adapter.refreshRequests, 1);
    refreshCompleter.complete();

    final responses = await Future.wait([firstRequest, secondRequest]);

    expect(responses.map((response) => response.statusCode), everyElement(200));
    expect(adapter.refreshRequests, 1);
    expect(
      adapter.protectedAuthorizationHeaders.where(
        (header) => header == 'Bearer new-access-token',
      ),
      hasLength(2),
    );
  });

  test('rejects original request when retry after refresh fails', () async {
    adapter = _TokenRefreshAdapter(retryStatusCode: 500);
    dio.httpClientAdapter = adapter;

    await expectLater(
      dio.get<void>('/protected'),
      throwsA(
        isA<DioException>().having(
          (error) => error.response?.statusCode,
          'statusCode',
          500,
        ),
      ),
    );

    expect(adapter.refreshRequests, 1);
    expect(sessionInvalidator.signOutCalled, isFalse);
  });

  test('locally signs out when refresh token request returns 401', () async {
    adapter = _TokenRefreshAdapter(refreshStatusCode: 401);
    dio.httpClientAdapter = adapter;

    await expectLater(
      dio.get<void>('/protected'),
      throwsA(isA<DioException>()),
    );

    expect(
      adapter.requestedPaths,
      containsAll(['/protected', '/refresh-token']),
    );
    expect(adapter.refreshRequests, 1);
    expect(sessionInvalidator.signOutCalled, isTrue);
    expect(tokenLocalDataSource.deleteTokenCalled, isTrue);
  });

  test(
    'continues authentication requests when local token lookup fails',
    () async {
      tokenLocalDataSource.throwOnGetToken = true;

      final response = await dio.post<String>(Endpoint.signIn);

      expect(response.statusCode, 200);
      expect(adapter.protectedAuthorizationHeaders, isEmpty);
    },
  );

  test(
    'rejects protected requests locally when local token lookup fails',
    () async {
      tokenLocalDataSource.throwOnGetToken = true;

      await expectLater(
        dio.get<void>('/protected'),
        throwsA(
          isA<DioException>().having(
            (error) => error.message,
            'message',
            contains('Authentication token is unavailable'),
          ),
        ),
      );

      expect(adapter.requestedPaths, isEmpty);
      expect(sessionInvalidator.signOutCalled, isFalse);
      expect(tokenLocalDataSource.deleteTokenCalled, isFalse);
    },
  );

  test(
    'missing refresh headers rejects request and signs out locally',
    () async {
      adapter = _TokenRefreshAdapter(omitRefreshHeaders: true);
      dio.httpClientAdapter = adapter;

      await expectLater(
        dio.get<void>('/protected'),
        throwsA(isA<DioException>()),
      );

      expect(adapter.refreshRequests, 1);
      expect(sessionInvalidator.signOutCalled, isTrue);
      expect(tokenLocalDataSource.deleteTokenCalled, isTrue);
    },
  );
}

Future<void> _flushMicrotasks() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _TokenRefreshAdapter implements HttpClientAdapter {
  _TokenRefreshAdapter({
    this.refreshStatusCode = 200,
    this.retryStatusCode = 200,
    this.refreshCompleter,
    this.omitRefreshHeaders = false,
  });

  final int refreshStatusCode;
  final int retryStatusCode;
  final Completer<void>? refreshCompleter;
  final bool omitRefreshHeaders;

  final requestedPaths = <String>[];
  final protectedAuthorizationHeaders = <String?>[];
  final refreshAuthorizationHeaders = <String?>[];
  final _pathRequestCounts = <String, int>{};

  int refreshRequests = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestedPaths.add(options.path);
    if (options.path == '/refresh-token') {
      refreshRequests++;
      refreshAuthorizationHeaders.add(
        options.headers['Authorization-refresh']?.toString(),
      );
      await refreshCompleter?.future;
      return ResponseBody.fromString(
        '{"message":"Refresh response"}',
        refreshStatusCode,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
          if (refreshStatusCode == 200 && !omitRefreshHeaders) ...{
            'authorization': ['new-access-token'],
            'authorization-refresh': ['new-refresh-token'],
          },
        },
      );
    }

    if (options.path.startsWith('/protected')) {
      protectedAuthorizationHeaders.add(
        options.headers['Authorization']?.toString(),
      );
      final requestCount = (_pathRequestCounts[options.path] ?? 0) + 1;
      _pathRequestCounts[options.path] = requestCount;

      if (requestCount == 1) {
        return _response(401, '{"message":"Unauthorized"}');
      }

      return _response(retryStatusCode, '{"message":"Retried response"}');
    }

    return _response(200, '{"message":"OK"}');
  }

  ResponseBody _response(int statusCode, String body) {
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FakeTokenLocalDataSource implements TokenLocalDataSource {
  TokenEntity token = const TokenEntity(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
  );
  TokenEntity? storedToken;
  bool deleteTokenCalled = false;
  int storeTokensCallCount = 0;
  bool throwOnGetToken = false;

  @override
  Future<void> deleteToken() async {
    deleteTokenCalled = true;
  }

  @override
  Future<TokenEntity> getToken() async {
    if (throwOnGetToken) {
      throw Exception('token unavailable');
    }
    return token;
  }

  @override
  Future<void> storeAuthToken(String token) async {}

  @override
  Future<void> storeTokens(TokenEntity token) async {
    storeTokensCallCount++;
    storedToken = token;
    this.token = token;
  }
}

class _FakeTokenSessionInvalidator implements TokenSessionInvalidator {
  _FakeTokenSessionInvalidator(this._tokenLocalDataSource);

  final TokenLocalDataSource _tokenLocalDataSource;
  bool signOutCalled = false;

  @override
  Future<void> signOutLocally() async {
    signOutCalled = true;
    await _tokenLocalDataSource.deleteToken();
  }
}
