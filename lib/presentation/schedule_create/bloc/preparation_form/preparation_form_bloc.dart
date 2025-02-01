import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';

part 'preparation_form_event.dart';
part 'preparation_form_state.dart';

@Injectable()
class PreparationFormBloc
    extends Bloc<PreparationFormEvent, PreparationFormState> {
  PreparationFormBloc() : super(PreparationFormState()) {
    on<PreparationFormEditRequested>(_onPreparationFormEditRequested);
    on<PreparationFormPreparationStepAdded>(
        _onPreparationFormPreparationStepAdded);
    on<PreparationFormPreparationStepRemoved>(
        _onPreparationFormPreparationStepRemoved);
    on<PreparationFormPreparationStepNameChanged>(
        _onPreparationFormPreparationStepNameChanged);
    on<PreparationFormPreparationStepTimeChanged>(
        _onPreparationFormPreparationStepTimeChanged);
    on<PreparationFormPreparationStepOrderChanged>(
        _onPreparationFormPreparationStepOrderChanged);
  }

  void _onPreparationFormEditRequested(
    PreparationFormEditRequested event,
    Emitter<PreparationFormState> emit,
  ) {
    final PreparationFormState preparationFormState =
        PreparationFormState.fromEntity(event.preparationEntity);

    emit(state.copyWith(
      status: PreparationFormStatus.success,
      preparationStepList: preparationFormState.preparationStepList,
    ));
  }

  void _onPreparationFormPreparationStepAdded(
    PreparationFormPreparationStepAdded event,
    Emitter<PreparationFormState> emit,
  ) {
    emit(state.copyWith(
      preparationStepList: [
        ...state.preparationStepList,
        event.preparationStep,
      ],
    ));
  }

  void _onPreparationFormPreparationStepRemoved(
    PreparationFormPreparationStepRemoved event,
    Emitter<PreparationFormState> emit,
  ) {
    final removedElement = state.preparationStepList
        .firstWhere((element) => element.id == event.preparationStepId);
    final removedList = state.copyWith(
      preparationStepList: state.preparationStepList
          .where((element) => element.id != event.preparationStepId)
          .toList(),
    );

    for (var i = 0; i < removedList.preparationStepList.length; i++) {
      if (removedElement.order < removedList.preparationStepList[i].order) {
        removedList.preparationStepList[i] =
            removedList.preparationStepList[i].copyWith(
          order: removedList.preparationStepList[i].order - 1,
        );
      }
    }

    emit(removedList);
  }

  void _onPreparationFormPreparationStepNameChanged(
    PreparationFormPreparationStepNameChanged event,
    Emitter<PreparationFormState> emit,
  ) {
    final changedList = state;

    for (var i = 0; i < state.preparationStepList.length; i++) {
      if (state.preparationStepList[i].id == event.preparationStepId) {
        changedList.preparationStepList[i] =
            changedList.preparationStepList[i].copyWith(
          preparationName: event.preparationStepName,
        );
      }
    }

    emit(changedList);
  }

  void _onPreparationFormPreparationStepTimeChanged(
    PreparationFormPreparationStepTimeChanged event,
    Emitter<PreparationFormState> emit,
  ) {
    final changedList = state;

    for (var i = 0; i < state.preparationStepList.length; i++) {
      if (state.preparationStepList[i].id == event.preparationStepId) {
        changedList.preparationStepList[i] =
            changedList.preparationStepList[i].copyWith(
          preparationTime: event.preparationStepTime,
        );
      }
    }

    emit(changedList);
  }

  void _onPreparationFormPreparationStepOrderChanged(
    PreparationFormPreparationStepOrderChanged event,
    Emitter<PreparationFormState> emit,
  ) {
    final changedList = state;
    for (var i = 0; i < state.preparationStepList.length; i++) {
      var index = event.preparationStepOrder.indexOf(i);
      changedList.preparationStepList[i] =
          changedList.preparationStepList[i].copyWith(
        order: index,
      );
    }

    emit(changedList);
  }
}
