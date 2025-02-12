import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

part 'preparation_step_name_state.dart';

class PreparationStepNameCubit extends Cubit<PreparationStepNameState> {
  PreparationStepNameCubit() : super(PreparationStepNameState());

  void nameChanged(String preparationName) {
    emit(state.copyWith(preparationName: preparationName));
  }

  void selectionToggled() {
    emit(state.copyWith(
      status: state.status == PreparationStepNameStatus.selected
          ? PreparationStepNameStatus.unselected
          : PreparationStepNameStatus.selected,
    ));
  }

  void preparationStepSaved() {
    emit(state.copyWith(status: PreparationStepNameStatus.selected));
  }

  @override
  Future<void> close() {
    state.focusNode.dispose();
    return super.close();
  }
}
