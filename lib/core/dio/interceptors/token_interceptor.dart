import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:on_time_front/data/data_sources/token_local_data_source.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/domain/entities/token_entity.dart';
import 'package:on_time_front/domain/repositories/user_repository.dart';

class TokenInterceptor implements InterceptorsWrapper {
  static const _refreshTokenPath = '/refresh-token';
  static const _retryAfterRefreshKey = 'tokenInterceptor.retryAfterRefresh';

  final Dio dio;
  TokenInterceptor(this.dio);
  final TokenLocalDataSource tokenLocalDataSource =
      getIt.get<TokenLocalDataSource>();

  // when accessToken is expired & having multiple requests call
  // this variable to lock others request to make sure only trigger call refresh token 01 times
  // to prevent duplicate refresh call
  bool _isRefreshing = false;

  // when having multiple requests call at the same time, you need to store them in a list
  // then loop this list to retry every request later, after call refresh token success
  final _requestsNeedRetry =
      <({RequestOptions options, ErrorInterceptorHandler handler})>[];

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      final token = await tokenLocalDataSource.getToken();

      options.headers['Authorization'] = 'Bearer ${token.accessToken}';
    } catch (e) {
      debugPrint(e.toString());
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (_shouldRefreshToken(err)) {
      final response = err.response;
      // if hasn't not refreshing yet, let's start it
      _requestsNeedRetry.add((options: err.requestOptions, handler: handler));

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

  Future<bool> _refreshToken() async {
    try {
      final tokenEntity = await tokenLocalDataSource.getToken();
      final refreshToken = tokenEntity.refreshToken;

      final res = await dio.get(
        _refreshTokenPath,
        options: Options(
          extra: {
            _retryAfterRefreshKey: true,
          },
          headers: {
            'Authorization-refresh': 'Bearer $refreshToken',
          },
        ),
      );
      if (res.statusCode == 200) {
        debugPrint("token refreshing success");
        final accessToken = res.headers.value('authorization');
        final refreshedRefreshToken =
            res.headers.value('authorization-refresh');
        if (accessToken == null || refreshedRefreshToken == null) {
          throw StateError(
              'Refresh response must include authorization and authorization-refresh headers');
        }
        await tokenLocalDataSource.storeTokens(
          TokenEntity(
            accessToken: accessToken,
            refreshToken: refreshedRefreshToken,
          ),
        );
        return true;
      } else {
        debugPrint("refresh token fail ${res.statusMessage ?? res.toString()}");
        return false;
      }
    } catch (error) {
      debugPrint("refresh token fail $error");
      return false;
    }
  }

  Future<void> _retryRequests(
    List<({RequestOptions options, ErrorInterceptorHandler handler})> requests,
  ) async {
    await Future.wait(
      requests.map((requestNeedRetry) async {
        final options = requestNeedRetry.options;
        options.extra[_retryAfterRefreshKey] = true;

        try {
          final response = await dio.fetch(options);
          requestNeedRetry.handler.resolve(response);
        } on DioException catch (error) {
          requestNeedRetry.handler.reject(error);
        } catch (error) {
          requestNeedRetry.handler.reject(
            DioException(
              requestOptions: options,
              error: error,
            ),
          );
        }
      }),
    );
  }

  Future<void> _signOutLocally() async {
    try {
      await getIt.get<UserRepository>().signOut();
    } catch (_) {
      await tokenLocalDataSource.deleteToken();
    }
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    handler.next(response);
  }
}
