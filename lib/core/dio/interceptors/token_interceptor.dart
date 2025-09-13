import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:on_time_front/data/data_sources/token_local_data_source.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/domain/use-cases/sign_out_use_case.dart';

class TokenInterceptor implements InterceptorsWrapper {
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
    final response = err.response;
    if (response != null &&
        // status code for unauthorized usually 401
        response.statusCode == 401 &&
        // refresh token call maybe fail by it self
        // eg: when refreshToken also is expired -> can't get new accessToken
        // usually server also return 401 unauthorized for this case
        // need to exlude it to prevent loop infinite call
        response.requestOptions.path != "/refresh-token") {
      // if hasn't not refreshing yet, let's start it
      if (!_isRefreshing) {
        _isRefreshing = true;

        // add request (requestOptions and handler) to queue and wait to retry later
        _requestsNeedRetry
            .add((options: response.requestOptions, handler: handler));

        // call api refresh token
        final isRefreshSuccess = await _refreshToken();

        if (isRefreshSuccess) {
          // refresh success, loop requests need retry
          for (var requestNeedRetry in _requestsNeedRetry) {
            // don't need set new accessToken to header here, because these retry
            // will go through onRequest callback above (where new accessToken will be set to header)

            // won't use await because this loop will take longer -> maybe throw: Unhandled Exception: Concurrent modification during iteration
            // because method _requestsNeedRetry.add() is called at the same time
            // final response = await dio.fetch(requestNeedRetry.options);
            // requestNeedRetry.handler.resolve(response);

            dio.fetch(requestNeedRetry.options).then((response) {
              requestNeedRetry.handler.resolve(response);
            }).catchError((_) {});
          }

          _requestsNeedRetry.clear();
          _isRefreshing = false;
        } else {
          _requestsNeedRetry.clear();
          // if refresh fail, force logout user here
          try {
            await getIt.get<SignOutUseCase>().call();
          } catch (_) {
            await tokenLocalDataSource.deleteToken();
          }
          _isRefreshing = false;
        }
      } else {
        // if refresh flow is processing, add this request to queue and wait to retry later
        _requestsNeedRetry
            .add((options: response.requestOptions, handler: handler));
      }
    } else {
      // ignore other error is not unauthorized
      return handler.next(err);
    }
  }

  Future<bool> _refreshToken() async {
    try {
      final tokenEntity = await tokenLocalDataSource.getToken();
      final refreshToken = tokenEntity.refreshToken;

      final res = await dio.get(
        '/refresh-token',
        options: Options(
          headers: {
            'Authorization-refresh': 'Bearer $refreshToken',
          },
        ),
      );
      if (res.statusCode == 200) {
        debugPrint("token refreshing success");
        final authToken = res.headers['authorization']![0];
        // save new access + refresh token to your local storage for using later
        await tokenLocalDataSource.storeAuthToken(authToken);
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

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    handler.next(response);
  }
}
