import 'package:injectable/injectable.dart';
import '../entities/schedule_save.dart';
import '../entities/schedule_time_correction.dart';
import '../repositories/schedule_time_correction_repository.dart';
import 'schedule_mutation_alarm_effects_coordinator.dart';

@Injectable()
class ScheduleTimeCorrectionWorkflow {
  ScheduleTimeCorrectionWorkflow(this.repository, this.effects);
  final ScheduleTimeCorrectionRepository repository;
  final ScheduleMutationAlarmEffectsCoordinator effects;
  final _pending =
      <ScheduleTimeCorrectionCommand, Future<ScheduleSaveReceipt>>{};
  final _delivery = Expando<Future<ScheduleSaveReceipt>>();

  Future<ScheduleSaveReceipt> confirm(ScheduleTimeCorrectionCommand command) {
    final existing = _pending[command];
    if (existing != null) return existing;
    final future = _confirm(command);
    _pending[command] = future;
    future.then(
      (_) {
        _pending.remove(command);
      },
      onError: (Object _, StackTrace __) {
        _pending.remove(command);
      },
    );
    return future;
  }

  Future<ScheduleSaveReceipt> _confirm(
    ScheduleTimeCorrectionCommand command,
  ) async => retryDelivery(await repository.confirm(command));

  Future<ScheduleSaveReceipt> retryDelivery(ScheduleSaveReceipt receipt) {
    final existing = _delivery[receipt];
    if (existing != null) return existing;
    final future = _retryDelivery(receipt);
    _delivery[receipt] = future;
    future.then(
      (_) {
        _delivery[receipt] = null;
      },
      onError: (Object _, StackTrace __) {
        _delivery[receipt] = null;
      },
    );
    return future;
  }

  Future<ScheduleSaveReceipt> _retryDelivery(
    ScheduleSaveReceipt receipt,
  ) async {
    if (!repository.isCurrent(receipt)) {
      return receipt.withDeliveryPending(true);
    }
    try {
      final complete = await effects.afterCommit();
      return receipt.withDeliveryPending(
        !complete || !repository.isCurrent(receipt),
      );
    } catch (_) {
      return receipt.withDeliveryPending(true);
    }
  }
}
