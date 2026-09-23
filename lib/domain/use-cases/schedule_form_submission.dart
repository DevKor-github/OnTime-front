import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';
import 'package:on_time_front/domain/recurrence/recurring_schedule.dart';
import 'package:equatable/equatable.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_preparation_mode.dart';

class ScheduleFormSubmission extends Equatable {
  final ScheduleEntity schedule;
  final PreparationEntity preparation;
  final bool preparationChanged;
  final SchedulePreparationMode? originalPreparationMode;
  final ScheduleEntity? originalSchedule;
  final RecurrenceRule? recurrenceRule;
  final RecurringEditScope recurringScope;
  final bool recurrenceCountChanged;
  final Set<String> excludedSlots;
  final bool confirmDetached;
  final String? reviewedFirstSlotKey;

  const ScheduleFormSubmission({
    required this.schedule,
    required this.preparation,
    required this.preparationChanged,
    this.originalPreparationMode,
    this.originalSchedule,
    this.recurrenceRule,
    this.recurringScope = RecurringEditScope.occurrence,
    this.recurrenceCountChanged = false,
    this.excludedSlots = const {},
    this.confirmDetached = false,
    this.reviewedFirstSlotKey,
  });

  @override
  List<Object?> get props => [
    schedule,
    preparation,
    preparationChanged,
    originalPreparationMode,
    originalSchedule,
    recurrenceRule,
    recurringScope,
    recurrenceCountChanged,
    excludedSlots,
    confirmDetached,
    reviewedFirstSlotKey,
  ];
}
