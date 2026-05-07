import 'package:dio/dio.dart';
import 'package:on_time_front/core/logging/app_logger.dart';

/// A wrapper transformer that logs the exact serialized request payload
/// produced by Dio's inner transformer. This reflects the precise string
/// sent over the wire (JSON, form-url-encoded, etc.).
class LoggingTransformer implements Transformer {
  final Transformer _inner;

  LoggingTransformer({Transformer? inner})
      : _inner = inner ?? BackgroundTransformer();

  @override
  Future<String> transformRequest(RequestOptions options) async {
    final body = await _inner.transformRequest(options);
    AppLogger.debug(
      'Serialized request body=${AppLogger.omitted} '
      '${options.method} ${AppLogger.redactUri(options.uri)} bytes=${body.length}',
    );
    return body;
  }

  @override
  Future transformResponse(
      RequestOptions options, ResponseBody responseBody) async {
    return _inner.transformResponse(options, responseBody);
  }
}
