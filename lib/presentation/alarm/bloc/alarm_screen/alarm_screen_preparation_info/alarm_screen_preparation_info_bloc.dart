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
    on<AlarmScreenPreparationLoadingRequested>(_onLoadingRequested);
    on<AlarmScreenPreparationSubscriptionRequested>(_onSubscriptionRequested);
  }

  void _onLoadingRequested(AlarmScreenPreparationLoadingRequested event,
      Emitter<AlarmScreenPreparationInfoState> emit) {
    emit(AlarmScreenPreparationInfoLoadInProgress());
  }

  Future<void> _onSubscriptionRequested(
      AlarmScreenPreparationSubscriptionRequested event,
      Emitter<AlarmScreenPreparationInfoState> emit) async {
    add(AlarmScreenPreparationLoadingRequested());

    try {
      final PreparationEntity prepEntity =
          await getPreparationByScheduleIdUseCase(event.scheduleId);

      final List<PreparationStepEntity> steps = prepEntity.preparationStepList;
      final int totalPreparationTime =
          steps.fold(0, (sum, step) => sum + step.preparationTime.inSeconds);

      final int totalRemainingTime = totalPreparationTime;
      final List<bool> preparationCompleted =
          List<bool>.filled(steps.length, false);

      final int preparationRemainingTime =
          steps.isNotEmpty ? steps[0].preparationTime.inSeconds : 0;

      emit(AlarmScreenPreparationLoadSuccess(
        preparationSteps: steps,
        currentIndex: 0,
        preparationRemainingTime: preparationRemainingTime,
        totalPreparationRemainingTime: totalRemainingTime,
        preparationCompleted: preparationCompleted,
        schedule: event.schedule,
      ));
    } catch (e) {
      emit(AlarmScreenPreparationLoadFailure(e.toString()));
    }
  }
}
