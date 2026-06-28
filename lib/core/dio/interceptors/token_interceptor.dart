import 'package:dio/dio.dart';
import 'package:on_time_front/core/constants/endpoint.dart';
import 'package:on_time_front/core/dio/interceptors/token_session_invalidator.dart';
import 'package:on_time_front/core/logging/app_logger.dart';
import 'package:on_time_front/data/data_sources/token_local_data_source.dart';
import 'package:on_time_front/domain/entities/token_entity.dart';

class TokenInterceptor implements InterceptorsWrapper {
  static const _refreshTokenPath = '/refresh-token';
  static const _retryAfterRefreshKey = 'tokenInterceptor.retryAfterRefresh';
  static const _tokenUnavailableMessage =
      'Authentication token is unavailable for a protected request';

  static bool _isRefreshing = false;
  static final _requestsNeedRetry = <_RequestNeedingRetry>[];

  final Dio dio;
  final TokenLocalDataSource tokenLocalDataSource;
  final TokenSessionInvalidator _sessionInvalidator;

  TokenInterceptor(
    this.dio, {
    required this.tokenLocalDataSource,
    required TokenSessionInvalidator sessionInvalidator,
  }) : _sessionInvalidator = sessionInvalidator;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final token = await tokenLocalDataSource.getToken();

      options.headers['Authorization'] = 'Bearer ${token.accessToken}';
    } catch (error) {
      AppLogger.debug(
        'token load failed for request errorType=${error.runtimeType}',
      );
      if (!_allowsMissingToken(options.path)) {
        return handler.reject(
          DioException(
            requestOptions: options,
            error: error,
            message: _tokenUnavailableMessage,
          ),
        );
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (_shouldRefreshToken(err)) {
      final response = err.response;
      // if hasn't not refreshing yet, let's start it
      _requestsNeedRetry.add(
        _RequestNeedingRetry(
          dio: dio,
          options: err.requestOptions,
          handler: handler,
        ),
      );

      if (!_isRefreshing) {
        _isRefreshing = true;

        // call api refresh token
        final isRefreshSuccess = await _refreshToken();

        try {
          if (isRefreshSuccess) {
            while (_requestsNeedRetry.isNotEmpty) {
              final requestsNeedRetry = List.of(_requestsNeedRetry);
              _requestsNeedRetry.clear();
              await _retryRequests(requestsNeedRetry);
            }
          } else {
            for (final requestNeedRetry in _requestsNeedRetry) {
              requestNeedRetry.handler.reject(
                DioException(
                  requestOptions: requestNeedRetry.options,
                  response: response,
                  type: err.type,
                  error: err.error,
                  message: err.message,
                ),
              );
            }
            _requestsNeedRetry.clear();
            // Force a local logout when the refresh token is rejected. The full
            // sign-out use case may make authenticated cleanup calls, which can
            // deadlock while the interceptor is already refreshing.
            await _signOutLocally();
          }
        } finally {
          _isRefreshing = false;
        }
      }
    } else {
      // ignore other error is not unauthorized
      return handler.next(err);
    }
  }

  bool _shouldRefreshToken(DioException err) {
    final response = err.response;
    if (response?.statusCode != 401) {
      return false;
    }

    final requestOptions = err.requestOptions;
    return requestOptions.path != _refreshTokenPath &&
        requestOptions.extra[_retryAfterRefreshKey] != true;
  }

  bool _allowsMissingToken(String path) {
    return path == Endpoint.signIn ||
        path == Endpoint.signUp ||
        path == Endpoint.signInWithGoogle ||
        path == Endpoint.signInWithApple ||
        path == _refreshTokenPath;
  }

  Future<bool> _refreshToken() async {
    try {
      final tokenEntity = await tokenLocalDataSource.getToken();
      final refreshToken = tokenEntity.refreshToken;

      final res = await dio.get(
        _refreshTokenPath,
        options: Options(
          extra: {_retryAfterRefreshKey: true},
          headers: {'Authorization-refresh': 'Bearer $refreshToken'},
        ),
      );
      if (res.statusCode == 200) {
        AppLogger.debug('token refreshing success');
        final accessToken = res.headers.value('authorization');
        final refreshedRefreshToken = res.headers.value(
          'authorization-refresh',
        );
        if (accessToken == null || refreshedRefreshToken == null) {
          throw StateError(
            'Refresh response must include authorization and authorization-refresh headers',
          );
        }
        await tokenLocalDataSource.storeTokens(
          TokenEntity(
            accessToken: accessToken,
            refreshToken: refreshedRefreshToken,
          ),
        );
        return true;
      } else {
        AppLogger.debug(
          'refresh token failed status=${res.statusCode} '
          'message=${res.statusMessage}',
        );
        return false;
      }
    } catch (error) {
      AppLogger.debug('refresh token failed errorType=${error.runtimeType}');
      return false;
    }
  }

  Future<void> _retryRequests(List<_RequestNeedingRetry> requests) async {
    await Future.wait(
      requests.map((requestNeedRetry) async {
        final options = requestNeedRetry.options;
        options.extra[_retryAfterRefreshKey] = true;

        try {
          final response = await requestNeedRetry.dio.fetch(options);
          requestNeedRetry.handler.resolve(response);
        } on DioException catch (error) {
          requestNeedRetry.handler.reject(error);
        } catch (error) {
          requestNeedRetry.handler.reject(
            DioException(requestOptions: options, error: error),
          );
        }
      }),
    );
  }

  Future<void> _signOutLocally() async {
    await _sessionInvalidator.signOutLocally();
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    handler.next(response);
  }
}

class _RequestNeedingRetry {
  const _RequestNeedingRetry({
    required this.dio,
    required this.options,
    required this.handler,
  });

  final Dio dio;
  final RequestOptions options;
  final ErrorInterceptorHandler handler;
}
