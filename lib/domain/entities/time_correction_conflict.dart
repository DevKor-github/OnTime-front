import 'schedule_entity.dart';
import '../recurrence/recurrence_engine.dart';
import '../recurrence/recurrence_rule.dart';

class TimeCorrectionBusyInterval {
  const TimeCorrectionBusyInterval(
    this.schedule,
    this.preparationStartUtc,
    this.instantUtc,
  );
  final ScheduleEntity schedule;
  final DateTime preparationStartUtc;
  final DateTime instantUtc;
}

class TimeCorrectionConflict {
  const TimeCorrectionConflict({
    required this.slot,
    required this.other,
    this.otherSlotKey,
    this.persistent = false,
  });
  final RecurrenceSlot slot;
  final TimeCorrectionBusyInterval other;
  final String? otherSlotKey;
  final bool persistent;
}

class TimeCorrectionPossibleOverlap {
  const TimeCorrectionPossibleOverlap({
    required this.id,
    required this.name,
    required this.reason,
    this.originalCivil,
    this.timeZoneId,
    this.rule,
    this.earliestPreparationUtc,
    this.latestTargetUtc,
  });
  final String id;
  final String name;
  final String reason;
  final DateTime? originalCivil;
  final String? timeZoneId;
  final RecurrenceRule? rule;
  final DateTime? earliestPreparationUtc;
  final DateTime? latestTargetUtc;
  bool mayOverlap(DateTime startUtc, DateTime endUtc) =>
      (earliestPreparationUtc == null ||
          !earliestPreparationUtc!.isAfter(endUtc)) &&
      (latestTargetUtc == null || !latestTargetUtc!.isBefore(startUtc));
}

class TimeCorrectionConflictProof {
  TimeCorrectionConflictProof({
    required List<TimeCorrectionConflict> conflicts,
    required this.through,
    required this.workUnits,
    this.earliestPreparationUtc,
    this.latestTargetUtc,
    List<TimeCorrectionPossibleOverlap> possibleOverlaps = const [],
    List<RecurrenceSlot> proposedSlots = const [],
  }) : conflicts = List.unmodifiable(conflicts),
       possibleOverlaps = List.unmodifiable(possibleOverlaps),
       proposedSlots = List.unmodifiable(proposedSlots);
  final List<TimeCorrectionConflict> conflicts;
  final List<TimeCorrectionPossibleOverlap> possibleOverlaps;
  final List<RecurrenceSlot> proposedSlots;
  final DateTime through;
  final int workUnits;
  final DateTime? earliestPreparationUtc;
  final DateTime? latestTargetUtc;
}
