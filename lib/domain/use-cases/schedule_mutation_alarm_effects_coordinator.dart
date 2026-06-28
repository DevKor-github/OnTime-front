import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/logging/app_logger.dart';
import 'package:on_time_front/domain/use-cases/cancel_schedule_alarm_use_case.dart';
import 'package:on_time_front/domain/use-cases/reconcile_alarms_use_case.dart';

enum ScheduleMutationAlarmOperation { created, updated, deleted, finished }

@Injectable()
class ScheduleMutationAlarmEffectsCoordinator {
  static const _logTag = '[ScheduleMutationAlarmEffects]';

  final CancelScheduleAlarmUseCase _cancelScheduleAlarmUseCase;
  final ReconcileAlarmsUseCase _reconcileAlarmsUseCase;

  ScheduleMutationAlarmEffectsCoordinator(
    this._cancelScheduleAlarmUseCase,
    this._reconcileAlarmsUseCase,
  );

  Future<void> call({
    required ScheduleMutationAlarmOperation operation,
    required String scheduleId,
  }) async {
    if (_requiresTargetedCancellation(operation)) {
      await _cancelScheduleAlarmUseCase(scheduleId);
    }
    _reconcileBestEffort(operation, scheduleId);
  }

  bool _requiresTargetedCancellation(ScheduleMutationAlarmOperation operation) {
    return operation == ScheduleMutationAlarmOperation.deleted ||
        operation == ScheduleMutationAlarmOperation.finished;
  }

  void _reconcileBestEffort(
    ScheduleMutationAlarmOperation operation,
    String scheduleId,
  ) {
    unawaited(
      _reconcileAlarmsUseCase().then<void>((_) {}).catchError((
        Object error,
        StackTrace _,
      ) {
        AppLogger.debug(
          '$_logTag reconcile failed '
          'operation=${operation.name} '
          'scheduleId=$scheduleId '
          'errorType=${error.runtimeType}',
        );
      }),
    );
  }
}
