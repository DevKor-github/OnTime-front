import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/schedule_preparation_mode.dart';
import 'package:on_time_front/domain/use-cases/get_default_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_schedule_by_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_preparation_by_schedule_id_use_case.dart';
import 'package:uuid/uuid.dart';

class ScheduleFormDraft extends Equatable {
  final String id;
  final String? placeId;
  final String? placeName;
  final String? scheduleName;
  final DateTime? scheduleTime;
  final Duration? moveTime;
  final bool preparationChanged;
  final Duration? scheduleSpareTime;
  final String? scheduleNote;
  final PreparationEntity preparation;
  final SchedulePreparationMode? originalPreparationMode;

  const ScheduleFormDraft({
    required this.id,
    required this.placeId,
    required this.placeName,
    required this.scheduleName,
    required this.scheduleTime,
    required this.moveTime,
    required this.preparationChanged,
    required this.scheduleSpareTime,
    required this.scheduleNote,
    required this.preparation,
    this.originalPreparationMode,
  });

  @override
  List<Object?> get props => [
    id,
    placeId,
    placeName,
    scheduleName,
    scheduleTime,
    moveTime,
    preparationChanged,
    scheduleSpareTime,
    scheduleNote,
    preparation,
    originalPreparationMode,
  ];
}

@Injectable()
class LoadScheduleFormDraftUseCase {
  final LoadPreparationByScheduleIdUseCase _loadPreparationByScheduleIdUseCase;
  final GetPreparationByScheduleIdUseCase _getPreparationByScheduleIdUseCase;
  final GetDefaultPreparationUseCase _getDefaultPreparationUseCase;
  final GetScheduleByIdUseCase _getScheduleByIdUseCase;
  final DateTime Function() _now;
  final String Function() _newId;

  LoadScheduleFormDraftUseCase(
    this._loadPreparationByScheduleIdUseCase,
    this._getPreparationByScheduleIdUseCase,
    this._getDefaultPreparationUseCase,
    this._getScheduleByIdUseCase,
  ) : _now = DateTime.now,
      _newId = const Uuid().v7;

  LoadScheduleFormDraftUseCase.withOverrides(
    this._loadPreparationByScheduleIdUseCase,
    this._getPreparationByScheduleIdUseCase,
    this._getDefaultPreparationUseCase,
    this._getScheduleByIdUseCase, {
    required DateTime Function() now,
    required String Function() newId,
  }) : _now = now,
       _newId = newId;

  Future<ScheduleFormDraft> create({
    DateTime? initialDate,
    Duration? currentUserSpareTime,
  }) async {
    final defaultPreparation = await _getDefaultPreparationUseCase();

    return ScheduleFormDraft(
      id: _newId(),
      placeId: _newId(),
      placeName: null,
      scheduleName: null,
      scheduleTime: initialDate == null
          ? null
          : _initialScheduleTime(initialDate, _now()),
      moveTime: null,
      preparationChanged: false,
      scheduleSpareTime: currentUserSpareTime,
      scheduleNote: null,
      preparation: defaultPreparation,
      originalPreparationMode: null,
    );
  }

  Future<ScheduleFormDraft> edit(String scheduleId) async {
    await _loadPreparationByScheduleIdUseCase(scheduleId);
    final preparation = await _getPreparationByScheduleIdUseCase(scheduleId);
    final schedule = await _getScheduleByIdUseCase(scheduleId);

    return ScheduleFormDraft(
      id: schedule.id,
      placeId: schedule.place.id,
      placeName: schedule.place.placeName,
      scheduleName: schedule.scheduleName,
      scheduleTime: schedule.scheduleTime,
      moveTime: schedule.moveTime,
      preparationChanged: schedule.isChanged,
      scheduleSpareTime: schedule.scheduleSpareTime,
      scheduleNote: schedule.scheduleNote,
      preparation: preparation,
      originalPreparationMode: schedule.preparationMode,
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
