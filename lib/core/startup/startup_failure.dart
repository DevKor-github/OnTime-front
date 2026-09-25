/// Safe startup facts. Causes stay internal and are never display strings.
enum StartupStage {
  locale,
  lifecycle,
  temporaryFiles,
  store,
  dependencies,
  cleanup,
}

final class StartupFailure implements Exception {
  const StartupFailure(this.stage, this.cause, {this.allowsReset = false});
  final StartupStage stage;
  final Object cause;
  final bool allowsReset;
  @override
  String toString() => 'Startup is incomplete (${stage.name})';
}

/// Existing installation evidence cannot be treated as a fresh installation.
final class LocalStorePreservationRequired implements Exception {
  const LocalStorePreservationRequired();
  @override
  String toString() => 'Local store requires recovery';
}

Future<T> startupStage<T>(
  StartupStage stage,
  Future<T> Function() action,
) async {
  try {
    return await action();
  } catch (cause) {
    throw StartupFailure(
      stage,
      cause,
      allowsReset: cause is LocalStorePreservationRequired,
    );
  }
}
