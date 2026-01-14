import 'dart:io';

import 'package:dio/dio.dart';
import 'package:on_time_front/core/error/failures.dart';
import 'package:on_time_front/data/errors/data_failures.dart';

/// Maps thrown exceptions into a structured [Failure] tree.
///
/// Repositories should catch `Object` and map it here instead of rethrowing.
class ExceptionToFailureMapper {
  const ExceptionToFailureMapper._();

  static Failure map(Object error, StackTrace stackTrace) {
    if (error is Failure) return error;

    if (error is DioException) {
      return _mapDio(error, stackTrace);
    }

    if (error is SocketException) {
      return NetworkFailure(
        code: 'NETWORK_SOCKET',
        message: 'Network connection failed.',
        cause: error,
        stackTrace: stackTrace,
      );
    }

    if (error is FormatException) {
      return ParseFailure(
        code: 'PARSE_FORMAT',
        message: 'Failed to parse response.',
        cause: error,
        stackTrace: stackTrace,
      );
    }

    return UnexpectedFailure(
      code: 'UNEXPECTED',
      message: 'Unexpected error occurred.',
      cause: error,
      stackTrace: stackTrace,
    );
  }

  static Failure _mapDio(DioException err, StackTrace stackTrace) {
    final res = err.response;
    final status = res?.statusCode;

    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return NetworkFailure(
          code: 'NETWORK_TIMEOUT',
          message: 'Network request timed out.',
          cause: err,
          stackTrace: stackTrace,
        );

      case DioExceptionType.connectionError:
        return NetworkFailure(
          code: 'NETWORK_CONNECTION',
          message: 'Network connection error.',
          cause: err,
          stackTrace: stackTrace,
        );

      case DioExceptionType.badCertificate:
        return NetworkFailure(
          code: 'NETWORK_BAD_CERT',
          message: 'Bad TLS certificate.',
          cause: err,
          stackTrace: stackTrace,
        );

      case DioExceptionType.cancel:
        return NetworkFailure(
          code: 'NETWORK_CANCELLED',
          message: 'Request cancelled.',
          cause: err,
          stackTrace: stackTrace,
        );

      case DioExceptionType.badResponse:
        return ServerFailure(
          statusCode: status,
          code: 'HTTP_${status ?? 'UNKNOWN'}',
          message: 'Server responded with an error.',
          cause: err,
          stackTrace: stackTrace,
        );

      case DioExceptionType.unknown:
        // Often wraps SocketException etc.
        return NetworkFailure(
          code: 'NETWORK_UNKNOWN',
          message: 'Network error occurred.',
          cause: err,
          stackTrace: stackTrace,
        );
    }
  }
}


