library;

import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/use-cases/get_preparation_by_schedule_id_use_case.dart';

part 'alarm_screen_preparation_info_event.dart';
part 'alarm_screen_preparation_info_state.dart';

@injectable
class AlarmScreenPreparationInfoBloc extends Bloc<
    AlarmScreenPreparationInfoEvent, AlarmScreenPreparationInfoState> {
  final GetPreparationByScheduleIdUseCase getPreparationByScheduleIdUseCase;

  AlarmScreenPreparationInfoBloc(
      {required this.getPreparationByScheduleIdUseCase})
      : super(AlarmScreenPreparationInitial()) {
    on<AlarmScreenPreparationSubscriptionRequested>(_onSubscriptionRequested);
  }

  Future<void> _onSubscriptionRequested(
      AlarmScreenPreparationSubscriptionRequested event,
      Emitter<AlarmScreenPreparationInfoState> emit) async {
    emit(AlarmScreenPreparationInfoLoadInProgress());
    try {
      final PreparationEntity prepEntity =
          await getPreparationByScheduleIdUseCase(event.scheduleId);

      final List<PreparationStepEntity> steps = prepEntity.preparationStepList;
      final int totalPrepTime =
          steps.fold(0, (sum, step) => sum + step.preparationTime.inSeconds);

      final int totalRemainingTime = totalPrepTime;
      final List<bool> preparationCompleted =
          List<bool>.filled(steps.length, false);

      final int beforeOutTime = _calculateBeforeOutTime(event.schedule);
      final bool isLate = beforeOutTime < 0;
      final int preparationRemainingTime =
          steps.isNotEmpty ? steps[0].preparationTime.inSeconds : 0;

      emit(AlarmScreenPreparationLoadSuccess(
        preparationSteps: steps,
        currentIndex: 0,
        preparationRemainingTime: preparationRemainingTime,
        totalPreparationTime: totalPrepTime,
        totalPreparationRemainingTime: totalRemainingTime,
        beforeOutTime: beforeOutTime,
        isLate: isLate,
        preparationCompleted: preparationCompleted,
      ));
    } catch (e) {
      emit(AlarmScreenPreparationLoadFailure(e.toString()));
    }
  }

  int _calculateBeforeOutTime(ScheduleEntity schedule) {
    final DateTime now = DateTime.now();
    final Duration spareTime = schedule.scheduleSpareTime;
    final DateTime scheduleTime = schedule.scheduleTime;
    final Duration moveTime = schedule.moveTime;
    final Duration remainingDuration =
        scheduleTime.difference(now) - moveTime - spareTime;
    return remainingDuration.inSeconds;
  }
}
