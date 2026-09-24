import 'package:on_time_front/domain/recurrence/recurring_schedule.dart';
import 'package:equatable/equatable.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';

class ScheduleEditBaseline extends Equatable {
  const ScheduleEditBaseline({
    required this.store,
    required this.generation,
    required this.revision,
    this.incarnation,
    this.version,
    this.rootId,
    this.rootIncarnation,
    this.rootVersion,
  });
  final String store;
  final int generation;
  final int revision;
  final String? incarnation;
  final int? version;
  final String? rootId;
  final String? rootIncarnation;
  final int? rootVersion;
  @override
  List<Object?> get props => [
    store,
    generation,
    revision,
    incarnation,
    version,
    rootId,
    rootIncarnation,
    rootVersion,
  ];
}

class ScheduleEditSnapshot {
  const ScheduleEditSnapshot(
    this.schedule,
    this.preparation,
    this.baseline, {
    this.segment,
  });
  final RecurringSegment? segment;
  final ScheduleEntity schedule;
  final PreparationEntity preparation;
  final ScheduleEditBaseline baseline;
}

enum ScheduleSaveFailure { conflict, invalid, protected, unavailable }

class ScheduleSaveRejected implements Exception {
  const ScheduleSaveRejected(this.failure);
  final ScheduleSaveFailure failure;
}

class ScheduleSaveReceipt {
  const ScheduleSaveReceipt({
    required this.scheduleId,
    required this.mutationId,
    required this.generation,
    required this.changed,
    this.deliveryPending = false,
  });
  final String scheduleId;
  final String mutationId;
  final int generation;
  final bool changed;
  final bool deliveryPending;
  ScheduleSaveReceipt withDeliveryPending(bool value) => ScheduleSaveReceipt(
    scheduleId: scheduleId,
    mutationId: mutationId,
    generation: generation,
    changed: changed,
    deliveryPending: value,
  );
}
