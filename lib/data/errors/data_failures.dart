import 'package:on_time_front/core/error/failures.dart';

class ServerFailure extends Failure {
  const ServerFailure({
    required this.statusCode,
    required super.code,
    required super.message,
    super.cause,
    super.stackTrace,
  });

  final int? statusCode;
}

class CacheFailure extends Failure {
  const CacheFailure({
    required super.code,
    required super.message,
    super.cause,
    super.stackTrace,
  });
}

class ParseFailure extends Failure {
  const ParseFailure({
    required super.code,
    required super.message,
    super.cause,
    super.stackTrace,
  });
}
