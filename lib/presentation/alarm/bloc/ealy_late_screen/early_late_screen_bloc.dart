import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/presentation/shared/constants/constants.dart';

part 'early_late_screen_event.dart';
part 'early_late_screen_state.dart';

@injectable
class EarlyLateScreenBloc
    extends Bloc<EarlyLateScreenEvent, EarlyLateScreenState> {
  EarlyLateScreenBloc() : super(EarlyLateScreenInitial()) {
    on<LoadEarlyLateInfo>(_onLoadEarlyLateInfo);
    on<ChecklistLoaded>(_onLoadChecklist);
    on<ChecklistItemToggled>(_onToggleChecklistItem);
  }

  void _onLoadEarlyLateInfo(
      LoadEarlyLateInfo event, Emitter<EarlyLateScreenState> emit) {
    bool isLate = event.earlyLateTime < 0;
    int absSeconds = event.earlyLateTime.abs();
    int minuteValue = (absSeconds / 60).ceil();

    String earlylateMessage =
        isLate ? getLateMessage() : getEarlyMessage(minuteValue);

    emit(EarlyLateScreenLoadSuccess(
      checklist: List.generate(3, (index) => false),
      isLate: isLate,
      earlylateMessage: earlylateMessage,
    ));
  }

  void _onLoadChecklist(
      ChecklistLoaded event, Emitter<EarlyLateScreenState> emit) {
    if (state is EarlyLateScreenLoadSuccess) {
      final currentState = state as EarlyLateScreenLoadSuccess;
      emit(EarlyLateScreenLoadSuccess(
        checklist: event.checklist,
        isLate: currentState.isLate,
        earlylateMessage: currentState.earlylateMessage,
      ));
    }
  }

  void _onToggleChecklistItem(
      ChecklistItemToggled event, Emitter<EarlyLateScreenState> emit) {
    if (state is EarlyLateScreenLoadSuccess) {
      final currentState = state as EarlyLateScreenLoadSuccess;
      final updatedChecklist = List<bool>.from(currentState.checklist);
      updatedChecklist[event.index] = !updatedChecklist[event.index];

      emit(EarlyLateScreenLoadSuccess(
        checklist: updatedChecklist,
        isLate: currentState.isLate,
        earlylateMessage: currentState.earlylateMessage,
      ));
    }
  }
}
