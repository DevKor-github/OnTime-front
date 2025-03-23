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
  final GetPreparationByScheduleIdUseCase _getPreparationByScheduleIdUseCase;

  AlarmScreenPreparationInfoBloc(
    this._getPreparationByScheduleIdUseCase,
  ) : super(AlarmScreenPreparationInitial()) {
    on<AlarmScreenPreparationSubscriptionRequested>(_onSubscriptionRequested);
  }

  Future<void> _onSubscriptionRequested(
      AlarmScreenPreparationSubscriptionRequested event,
      Emitter<AlarmScreenPreparationInfoState> emit) async {
    emit(AlarmScreenPreparationInfoLoadInProgress());

    try {
      final PreparationEntity prepEntity =
          await _getPreparationByScheduleIdUseCase(event.scheduleId);

      final List<PreparationStepEntity> steps = prepEntity.preparationStepList;

      emit(AlarmScreenPreparationLoadSuccess(
        preparationSteps: steps,
        schedule: event.schedule,
      ));
    } catch (e) {
      emit(AlarmScreenPreparationLoadFailure(e.toString()));
    }
  }
}
