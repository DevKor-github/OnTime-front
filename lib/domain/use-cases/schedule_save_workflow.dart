import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/schedule_save.dart';
import 'package:on_time_front/domain/repositories/schedule_aggregate_repository.dart';
import 'package:on_time_front/domain/use-cases/schedule_form_submission.dart';
import 'package:on_time_front/domain/use-cases/schedule_mutation_alarm_effects_coordinator.dart';

@Injectable()
class ScheduleSaveWorkflow {
  ScheduleSaveWorkflow(this.repository, this.effects);
  final ScheduleAggregateRepository repository;
  final ScheduleMutationAlarmEffectsCoordinator effects;
  final _pending =
      <(bool, ScheduleFormSubmission), Future<ScheduleSaveReceipt>>{};
  final _delivery = Expando<Future<ScheduleSaveReceipt>>();
  Future<ScheduleSaveReceipt> save(
    ScheduleFormSubmission value, {
    required bool editing,
  }) {
    final key = (editing, value);
    final pending = _pending[key];
    if (pending != null) return pending;
    final future = _save(value, editing: editing);
    _pending[key] = future;
    future.then(
      (_) {
        _pending.remove(key);
      },
      onError: (Object _, StackTrace __) {
        _pending.remove(key);
      },
    );
    return future;
  }

  Future<ScheduleSaveReceipt> _save(
    ScheduleFormSubmission value, {
    required bool editing,
  }) async {
    final receipt = await repository.save(value, editing: editing);
    return retryDelivery(receipt);
  }

  Future<ScheduleSaveReceipt> retryDelivery(ScheduleSaveReceipt receipt) {
    final pending = _delivery[receipt];
    if (pending != null) return pending;
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
