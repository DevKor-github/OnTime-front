import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/input_models/preparation_name_input_model.dart';
import 'package:on_time_front/presentation/onboarding/preparation_time/input_models/preparation_time_input_model.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/cubit/preparation_step_form_cubit.dart';

part 'preparation_form_event.dart';
part 'preparation_form_state.dart';

@Injectable()
class PreparationFormBloc
    extends Bloc<PreparationFormEvent, PreparationFormState> {
  PreparationFormBloc() : super(PreparationFormState()) {
    on<PreparationFormEditRequested>(_onPreparationFormEditRequested);
    on<PreparationFormPreparationStepCreated>(
      _onPreparationFormPreparationStepCreated,
    );
    on<PreparationFormPreparationStepRemoved>(
      _onPreparationFormPreparationStepRemoved,
    );
    on<PreparationFormPreparationStepNameChanged>(
      _onPreparationFormPreparationStepNameChanged,
    );
    on<PreparationFormPreparationStepTimeChanged>(
      _onPreparationFormPreparationStepTimeChanged,
    );
    on<PreparationFormDraftStepNameChanged>(
      _onPreparationFormDraftStepNameChanged,
    );
    on<PreparationFormDraftStepTimeChanged>(
      _onPreparationFormDraftStepTimeChanged,
    );
    on<PreparationFormPreparationStepOrderChanged>(
      _onPreparationFormPreparationStepOrderChanged,
    );
    on<PreparationFormPreparationStepCreationRequested>(
      _onPreparationFormPreparationStepCreationRequested,
    );
    on<PreparationFormValidationRequested>(
      _onPreparationFormValidationRequested,
    );
  }

  void _onPreparationFormEditRequested(
    PreparationFormEditRequested event,
    Emitter<PreparationFormState> emit,
  ) {
    final PreparationFormState preparationFormState =
        PreparationFormState.fromEntity(event.preparationEntity);
    final isValid = _validate(preparationFormState.visiblePreparationStepList);
    emit(
      state.copyWith(
        status: PreparationFormStatus.initial,
        preparationStepList: preparationFormState.preparationStepList,
        clearAddingStepId: true,
        showValidationErrors: false,
        isValid: isValid,
      ),
    );
  }

  void _onPreparationFormPreparationStepCreated(
    PreparationFormPreparationStepCreated event,
    Emitter<PreparationFormState> emit,
  ) {
    if (state.status == PreparationFormStatus.adding) {
      final List<PreparationStepFormState> preparationStepList;
      if (event.preparationStep.preparationName.isValid) {
        preparationStepList = [
          ...state.preparationStepList,
          event.preparationStep,
        ];
      } else {
        preparationStepList = state.preparationStepList;
      }
      final isValid = _validate(preparationStepList);
      emit(
        state.copyWith(
          preparationStepList: preparationStepList,
          status: PreparationFormStatus.initial,
          clearAddingStepId: true,
          isValid: isValid,
        ),
      );
    }
  }

  void _onPreparationFormPreparationStepRemoved(
    PreparationFormPreparationStepRemoved event,
    Emitter<PreparationFormState> emit,
  ) {
    if (state.preparationStepList.length <= 1) {
      return;
    }

    final removedList = List<PreparationStepFormState>.from(
      state.preparationStepList,
    );
    removedList.removeWhere((element) => element.id == event.preparationStepId);

    final isValid = _validate(removedList);
    final removedAddingStep = state.addingStepId == event.preparationStepId;
    emit(
      state.copyWith(
        preparationStepList: removedList,
        status: removedAddingStep ? PreparationFormStatus.initial : null,
        clearAddingStepId: removedAddingStep,
        isValid: isValid,
      ),
    );
  }

  void _onPreparationFormPreparationStepNameChanged(
    PreparationFormPreparationStepNameChanged event,
    Emitter<PreparationFormState> emit,
  ) {
    final changedList = List<PreparationStepFormState>.from(
      state.preparationStepList,
    );
    changedList[event.index] = changedList[event.index].copyWith(
      preparationName: PreparationNameInputModel.dirty(
        event.preparationStepName,
      ),
    );

    final isValid = _validate(changedList);
    final shouldCommitAddingStep = _shouldCommitAddingStep(
      changedList[event.index],
    );
    emit(
      state.copyWith(
        preparationStepList: changedList,
        status: shouldCommitAddingStep ? PreparationFormStatus.initial : null,
        clearAddingStepId: shouldCommitAddingStep,
        isValid: isValid,
      ),
    );
  }

  void _onPreparationFormPreparationStepTimeChanged(
    PreparationFormPreparationStepTimeChanged event,
    Emitter<PreparationFormState> emit,
  ) {
    final changedList = List<PreparationStepFormState>.from(
      state.preparationStepList,
    );
    changedList[event.index] = changedList[event.index].copyWith(
      preparationTime: PreparationTimeInputModel.dirty(
        event.preparationStepTime,
      ),
    );
    final isValid = _validate(changedList);
    final shouldCommitAddingStep = _shouldCommitAddingStep(
      changedList[event.index],
    );
    emit(
      state.copyWith(
        preparationStepList: changedList,
        status: shouldCommitAddingStep ? PreparationFormStatus.initial : null,
        clearAddingStepId: shouldCommitAddingStep,
        isValid: isValid,
      ),
    );
  }

  bool _shouldCommitAddingStep(PreparationStepFormState step) {
    return step.id == state.addingStepId &&
        step.preparationName.isValid &&
        step.preparationTime.isValid;
  }

  void _onPreparationFormDraftStepNameChanged(
    PreparationFormDraftStepNameChanged event,
    Emitter<PreparationFormState> emit,
  ) {
    final draftIndex = state.preparationStepList.indexWhere(
      (step) => step.id == state.addingStepId,
    );
    if (draftIndex == -1) {
      return;
    }

    add(
      PreparationFormPreparationStepNameChanged(
        index: draftIndex,
        preparationStepName: event.preparationStepName,
      ),
    );
  }

  void _onPreparationFormDraftStepTimeChanged(
    PreparationFormDraftStepTimeChanged event,
    Emitter<PreparationFormState> emit,
  ) {
    final draftIndex = state.preparationStepList.indexWhere(
      (step) => step.id == state.addingStepId,
    );
    if (draftIndex == -1) {
      return;
    }

    add(
      PreparationFormPreparationStepTimeChanged(
        index: draftIndex,
        preparationStepTime: event.preparationStepTime,
      ),
    );
  }

  void _onPreparationFormPreparationStepOrderChanged(
    PreparationFormPreparationStepOrderChanged event,
    Emitter<PreparationFormState> emit,
  ) {
    final changedList = List<PreparationStepFormState>.from(
      state.preparationStepList,
    );
    int oldIndex = event.oldIndex;
    int newIndex = event.newIndex;
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final item = changedList.removeAt(oldIndex);
    changedList.insert(newIndex, item);

    final isValid = _validate(changedList);
    emit(state.copyWith(preparationStepList: changedList, isValid: isValid));
  }

  bool _validate(List<PreparationStepFormState> preparationStepList) {
    final isValid =
        preparationStepList.isNotEmpty &&
        Formz.validate(
          preparationStepList
              .map((e) => [e.preparationName, e.preparationTime])
              .expand((element) => element)
              .cast<FormzInput<dynamic, dynamic>>()
              .toList(),
        );
    return isValid;
  }

  void _onPreparationFormPreparationStepCreationRequested(
    PreparationFormPreparationStepCreationRequested event,
    Emitter<PreparationFormState> emit,
  ) {
    if (state.status == PreparationFormStatus.adding) {
      return;
    }

    final addedStep = PreparationStepFormState();
    final changedList = [...state.preparationStepList, addedStep];
    final isValid = _validate(changedList);
    emit(
      state.copyWith(
        status: PreparationFormStatus.adding,
        preparationStepList: changedList,
        addingStepId: addedStep.id,
        isValid: isValid,
      ),
    );
  }

  void _onPreparationFormValidationRequested(
    PreparationFormValidationRequested event,
    Emitter<PreparationFormState> emit,
  ) {
    emit(state.copyWith(showValidationErrors: true));
  }
}
