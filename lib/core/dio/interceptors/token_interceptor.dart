import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:on_time_front/data/data_sources/token_local_data_source.dart';

class TokenInterceptor implements InterceptorsWrapper {
  TokenInterceptor();
  final TokenLocalDataSource tokenLocalDataSource = TokenLocalDataSourceImpl();

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
    // if (err.response?.statusCode == 401) {
    //   final refreshToken = await storage.read(key: refreshTokenKey);
    //   final oldAccessToken = await storage.read(key: accessTokenKey);

    //   if (refreshToken != null) {
    //     debugPrint('refresh Token is not null');
    //     try {
    //       final response = await dio.post('$apiUrl/v1/user/token', data: {
    //         'refresh_token': refreshToken,
    //         'oldAccessToken': oldAccessToken // Removed the extra space in key
    //       });
    //       final newAccessToken = response.data['access_token'];
    //       await storage.write(key: accessTokenKey, value: newAccessToken);
    //       err.requestOptions.headers['Authorization'] =
    //           'Bearer $newAccessToken';
    //       return handler.resolve(await dio.request(err.requestOptions.path,
    //           options: Options(
    //               method: err.requestOptions.method,
    //               headers: err.requestOptions.headers),
    //           data: err.requestOptions.data,
    //           queryParameters: err.requestOptions.queryParameters));
    //     } catch (e) {
    //       // Log out or handle token refresh failure
    //     }
    //   }
    // }
    handler.next(err);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    handler.next(response);
  }
}
