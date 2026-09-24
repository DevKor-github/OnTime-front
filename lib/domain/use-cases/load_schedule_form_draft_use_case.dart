import 'package:on_time_front/domain/recurrence/recurring_schedule.dart';
import 'package:on_time_front/domain/entities/schedule_save.dart';
import 'package:on_time_front/domain/repositories/schedule_aggregate_repository.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/core/services/local_time_zone_service.dart';
import 'package:on_time_front/domain/entities/schedule_preparation_mode.dart';
import 'package:on_time_front/domain/use-cases/get_default_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_schedule_by_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_preparation_by_schedule_id_use_case.dart';
import 'package:uuid/uuid.dart';

class ScheduleFormDraft extends Equatable {
  final RecurringSegment? segment;
  final ScheduleEditBaseline? baseline;
  final String id;
  final String? placeId;
  final String? placeName;
  final String? scheduleName;
  final DateTime? scheduleTime;
  final String timeZoneId;
  final int? occurrenceOffsetSeconds;
  final Duration? moveTime;
  final bool preparationChanged;
  final Duration? scheduleSpareTime;
  final String? scheduleNote;
  final PreparationEntity preparation;
  final SchedulePreparationMode? originalPreparationMode;
  final ScheduleEntity? originalSchedule;

  const ScheduleFormDraft({
    this.segment,
    this.baseline,
    required this.id,
    required this.placeId,
    required this.placeName,
    required this.scheduleName,
    required this.scheduleTime,
    this.timeZoneId = 'UTC',
    this.occurrenceOffsetSeconds,
    required this.moveTime,
    required this.preparationChanged,
    required this.scheduleSpareTime,
    required this.scheduleNote,
    required this.preparation,
    this.originalPreparationMode,
    this.originalSchedule,
  });

  @override
  List<Object?> get props => [
    baseline,
    id,
    placeId,
    placeName,
    scheduleName,
    scheduleTime,
    timeZoneId,
    occurrenceOffsetSeconds,
    moveTime,
    preparationChanged,
    scheduleSpareTime,
    scheduleNote,
    preparation,
    originalPreparationMode,
    originalSchedule,
  ];
}

@Injectable()
class LoadScheduleFormDraftUseCase {
  final LoadPreparationByScheduleIdUseCase _loadPreparationByScheduleIdUseCase;
  final GetPreparationByScheduleIdUseCase _getPreparationByScheduleIdUseCase;
  final GetDefaultPreparationUseCase _getDefaultPreparationUseCase;
  final GetScheduleByIdUseCase _getScheduleByIdUseCase;
  final ScheduleAggregateRepository? _aggregate;
  final DateTime Function() _now;
  final String Function() _newId;
  final Future<String> Function() _timeZoneId;

  LoadScheduleFormDraftUseCase(
    this._loadPreparationByScheduleIdUseCase,
    this._getPreparationByScheduleIdUseCase,
    this._getDefaultPreparationUseCase,
    this._getScheduleByIdUseCase,
    ScheduleAggregateRepository aggregate,
  ) : _aggregate = aggregate,
      _now = DateTime.now,
      _newId = const Uuid().v7,
      _timeZoneId = LocalTimeZoneService.current;

  LoadScheduleFormDraftUseCase.withOverrides(
    this._loadPreparationByScheduleIdUseCase,
    this._getPreparationByScheduleIdUseCase,
    this._getDefaultPreparationUseCase,
    this._getScheduleByIdUseCase, {
    required DateTime Function() now,
    required String Function() newId,
    Future<String> Function()? timeZoneId,
    ScheduleAggregateRepository? aggregate,
  }) : _aggregate = aggregate,
       _now = now,
       _newId = newId,
       _timeZoneId = timeZoneId ?? LocalTimeZoneService.current;

  Future<ScheduleFormDraft> create({
    DateTime? initialDate,
    Duration? currentUserSpareTime,
  }) async {
    final snapshot = await _aggregate?.newDraft();
    final defaultPreparation =
        snapshot?.preparation ?? await _getDefaultPreparationUseCase();

    return ScheduleFormDraft(
      baseline: snapshot?.baseline,
      id: _newId(),
      placeId: _newId(),
      placeName: null,
      scheduleName: null,
      scheduleTime: initialDate == null
          ? null
          : _initialScheduleTime(initialDate, _now()),
      timeZoneId: await _timeZoneId(),
      occurrenceOffsetSeconds: null,
      moveTime: null,
      preparationChanged: false,
      scheduleSpareTime: currentUserSpareTime,
      scheduleNote: null,
      preparation: defaultPreparation,
      originalPreparationMode: null,
    );
  }

  Future<ScheduleFormDraft> edit(String scheduleId) async {
    final snapshot = await _aggregate?.readForEdit(scheduleId);
    if (snapshot == null) await _loadPreparationByScheduleIdUseCase(scheduleId);
    final preparation =
        snapshot?.preparation ??
        await _getPreparationByScheduleIdUseCase(scheduleId);
    final schedule =
        snapshot?.schedule ?? await _getScheduleByIdUseCase(scheduleId);

    return ScheduleFormDraft(
      segment: snapshot?.segment,
      baseline: snapshot?.baseline,
      id: schedule.id,
      placeId: schedule.place.id,
      placeName: schedule.place.placeName,
      scheduleName: schedule.scheduleName,
      scheduleTime: schedule.scheduleTime,
      timeZoneId: schedule.timeZoneId,
      occurrenceOffsetSeconds: schedule.occurrenceOffsetSeconds,
      moveTime: schedule.moveTime,
      preparationChanged: schedule.isChanged,
      scheduleSpareTime: schedule.scheduleSpareTime,
      scheduleNote: schedule.scheduleNote,
      preparation: preparation,
      originalPreparationMode: schedule.preparationMode,
      originalSchedule: schedule,
    );
  }

  DateTime _initialScheduleTime(DateTime initialDate, DateTime now) {
    final selectedDate = DateTime(
      initialDate.year,
      initialDate.month,
      initialDate.day,
    );
    final today = DateTime(now.year, now.month, now.day);
    final initialTime = selectedDate == today
        ? now.add(const Duration(minutes: 1))
        : now;
    return DateTime(
      initialDate.year,
      initialDate.month,
      initialDate.day,
      initialTime.hour,
      initialTime.minute,
    );
  }
}
