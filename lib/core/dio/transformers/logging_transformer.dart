import 'dart:developer';

import 'package:dio/dio.dart';

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
    try {
      log('🧾 Serialized body (${options.method} ${options.uri}): $body');
    } catch (_) {}
    return body;
  }

  @override
  Future transformResponse(
      RequestOptions options, ResponseBody responseBody) async {
    return _inner.transformResponse(options, responseBody);
  }
}
