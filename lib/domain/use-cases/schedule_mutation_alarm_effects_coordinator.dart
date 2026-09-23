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
    // Acceptance is synchronous after the durable commit, even if targeted
    // cancellation subsequently fails. The drain will retry from current data.
    final reconciliation = _reconcileAlarmsUseCase();
    _observe(reconciliation, operation, scheduleId);
    if (_requiresTargetedCancellation(operation)) {
      try {
        await _cancelScheduleAlarmUseCase(scheduleId);
      } catch (error) {
        AppLogger.debug(
          '$_logTag cancellation incomplete errorType=${error.runtimeType}',
        );
      }
    }
  }

  bool _requiresTargetedCancellation(ScheduleMutationAlarmOperation operation) {
    return operation == ScheduleMutationAlarmOperation.deleted ||
        operation == ScheduleMutationAlarmOperation.finished;
  }

  void _observe(
    Future<dynamic> reconciliation,
    ScheduleMutationAlarmOperation operation,
    String scheduleId,
  ) {
    unawaited(
      reconciliation.then<void>(
        (_) {},
        onError: (Object error, StackTrace _) {
          AppLogger.debug(
            '$_logTag reconcile failed operation=${operation.name} errorType=${error.runtimeType}',
          );
        },
      ),
    );
  }
}
