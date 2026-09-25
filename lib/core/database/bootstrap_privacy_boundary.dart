/// Both failures remain inspectable without rendering private exception data.
class BootstrapPrivacyCleanupFailure implements Exception {
  const BootstrapPrivacyCleanupFailure(this.bootstrapError, this.cleanupError);
  final Object bootstrapError;
  final Object cleanupError;
  @override
  String toString() => 'Local bootstrap failed and privacy cleanup is pending';
}

Future<void> bootstrapWithPrivacyCleanup({
  required Future<void> Function() bootstrap,
  required Future<void> Function() cleanup,
  bool Function(Object error)? shouldCleanup,
}) async {
  try {
    await bootstrap();
  } catch (error, stack) {
    if (shouldCleanup != null && !shouldCleanup(error)) {
      Error.throwWithStackTrace(error, stack);
    }
    try {
      await cleanup();
    } catch (cleanupError) {
      Error.throwWithStackTrace(
        BootstrapPrivacyCleanupFailure(error, cleanupError),
        stack,
      );
    }
    Error.throwWithStackTrace(error, stack);
  }
}
