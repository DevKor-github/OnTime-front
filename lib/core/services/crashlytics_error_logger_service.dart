import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/error/failures.dart';
import 'package:on_time_front/core/services/error_logger_service.dart';

/// Production error logger that reports failures to Firebase Crashlytics.
///
/// - Disabled on web and in debug mode.
/// - Keep messages concise; include structured context when possible.
@Singleton(as: ErrorLoggerService)
class CrashlyticsErrorLoggerService implements ErrorLoggerService {
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
      if (failure.stackTrace != null)
        debugPrint('stackTrace=${failure.stackTrace}');
      return;
    }

    if (kIsWeb) return;

    await FirebaseCrashlytics.instance.setCustomKey(
      'failure_code',
      failure.code,
    );
    if (hint != null) {
      await FirebaseCrashlytics.instance.setCustomKey('failure_hint', hint);
    }
    if (context != null) {
      for (final entry in context.entries) {
        final key = 'ctx_${entry.key}';
        final value = entry.value;
        if (value == null) continue;
        await FirebaseCrashlytics.instance.setCustomKey(key, value.toString());
      }
    }

    final reason = '[${failure.code}] ${failure.message}';
    final error = failure.cause ?? failure;
    final stack = failure.stackTrace;

    // Mark as non-fatal by default; allow callers to log fatal via main.dart hooks.
    await FirebaseCrashlytics.instance.recordError(
      error,
      stack,
      reason: reason,
      printDetails: false,
    );
  }
}
