import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/error/failures.dart';

/// Logs failures to an external system (Crashlytics, Sentry, etc.).
///
/// Keep this at the core layer so any layer can log without depending on UI.
abstract interface class ErrorLoggerService {
  Future<void> log(
    Failure failure, {
    String? hint,
    Map<String, Object?>? context,
  });
}

/// Default logger: logs to debug console in debug/profile.
///
/// In production, prefer providing another DI binding (e.g. Crashlytics).
class DefaultErrorLoggerService implements ErrorLoggerService {
  @override
  Future<void> log(
    Failure failure, {
    String? hint,
    Map<String, Object?>? context,
  }) async {
    if (kDebugMode) {
      debugPrint('[Failure] ${failure.code}: ${failure.message}');
      if (hint != null) debugPrint('hint=$hint');
      if (context != null) debugPrint('context=$context');
      if (failure.cause != null) debugPrint('cause=${failure.cause}');
      if (failure.stackTrace != null) debugPrint('stackTrace=${failure.stackTrace}');
    }
  }
}



