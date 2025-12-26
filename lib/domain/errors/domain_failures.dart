import 'package:on_time_front/core/error/failures.dart';

/// Domain-specific failures.
///
/// Keep these independent from infrastructure details (Dio, HTTP codes, etc.).

class PreparationChainFailure extends DataIntegrityFailure {
  const PreparationChainFailure._({
    required super.code,
    required super.message,
    super.cause,
    super.stackTrace,
  });

  factory PreparationChainFailure.noTail({
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return PreparationChainFailure._(
      code: 'PREP_NO_TAIL',
      message:
          'Preparation chain has no tail (no step with nextPreparationId=null).',
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  factory PreparationChainFailure.cycleDetected({
    required String atStepId,
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return PreparationChainFailure._(
      code: 'PREP_CYCLE_DETECTED',
      message: 'Preparation chain contains a cycle at stepId=$atStepId.',
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  factory PreparationChainFailure.broken({
    required int connectedCount,
    required int totalCount,
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return PreparationChainFailure._(
      code: 'PREP_BROKEN_CHAIN',
      message:
          'Preparation chain is broken ($connectedCount/$totalCount connected).',
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  factory PreparationChainFailure.multipleTails({
    required int tailCount,
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return PreparationChainFailure._(
      code: 'PREP_MULTIPLE_TAILS',
      message: 'Preparation chain has multiple tails (count=$tailCount).',
      cause: cause,
      stackTrace: stackTrace,
    );
  }
}

class ScheduleNotFoundFailure extends Failure {
  const ScheduleNotFoundFailure({super.cause, super.stackTrace})
    : super(code: 'SCHEDULE_NOT_FOUND', message: 'Schedule not found.');
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure({super.cause, super.stackTrace})
    : super(code: 'UNAUTHORIZED', message: 'Unauthorized.');
}
