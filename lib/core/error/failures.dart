/// Base failure type for Result-based error handling.
///
/// This is intentionally lightweight: code + message + optional stackTrace/cause.
abstract class Failure {
  const Failure({
    required this.code,
    required this.message,
    this.cause,
    this.stackTrace,
  });

  final String code;
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() => 'Failure(code: $code, message: $message, cause: $cause)';
}

/// Failures that are safe to show directly to users (e.g., form validation).
class ValidationFailure extends Failure {
  const ValidationFailure({
    required super.code,
    required super.message,
    super.cause,
    super.stackTrace,
  });
}

/// Failures related to connectivity, timeouts, DNS, etc.
class NetworkFailure extends Failure {
  const NetworkFailure({
    required super.code,
    required super.message,
    super.cause,
    super.stackTrace,
  });
}

/// Failures caused by unexpected/coding issues.
class UnexpectedFailure extends Failure {
  const UnexpectedFailure({
    required super.code,
    required super.message,
    super.cause,
    super.stackTrace,
  });
}

/// Failures caused by inconsistent/corrupted data (e.g., broken linked list).
class DataIntegrityFailure extends Failure {
  const DataIntegrityFailure({
    required super.code,
    required super.message,
    super.cause,
    super.stackTrace,
  });
}
