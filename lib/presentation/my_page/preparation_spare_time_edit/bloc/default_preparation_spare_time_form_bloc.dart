import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/use-cases/get_default_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/update_default_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/update_spare_time_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_user_use_case.dart';

part 'default_preparation_spare_time_form_event.dart';
part 'default_preparation_spare_time_form_state.dart';

@injectable
class DefaultPreparationSpareTimeFormBloc extends Bloc<
    DefaultPreparationSpareTimeFormEvent,
    DefaultPreparationSpareTimeFormState> {
  DefaultPreparationSpareTimeFormBloc(
    this._getDefaultPreparationUseCase,
    this._updateDefaultPreparationUseCase,
    this._updateSpareTimeUseCase,
    this._loadUserUseCase,
  ) : super(DefaultPreparationSpareTimeFormState()) {
    on<FormEditRequested>(_onFormEditRequested);
    on<SpareTimeIncreased>(_onSpareTimeIncreased);
    on<SpareTimeDecreased>(_onSpareTimeDecreased);
    on<FormSubmitted>(_onFormSubmitted);
  }

  final GetDefaultPreparationUseCase _getDefaultPreparationUseCase;
  final UpdateDefaultPreparationUseCase _updateDefaultPreparationUseCase;
  final UpdateSpareTimeUseCase _updateSpareTimeUseCase;
  final LoadUserUseCase _loadUserUseCase;
  final Duration lowerBound = Duration(minutes: 10);
  final Duration stepSize = Duration(minutes: 5);

  Future<void> _onFormEditRequested(FormEditRequested event,
      Emitter<DefaultPreparationSpareTimeFormState> emit) async {
    emit(state.copyWith(
      status: DefaultPreparationSpareTimeStatus.loading,
    ));

    final preparationResult = await _getDefaultPreparationUseCase();
    if (preparationResult.isFailure) {
      final failure = preparationResult.failureOrNull!;
      addError(failure, failure.stackTrace);
      emit(state.copyWith(
        status: DefaultPreparationSpareTimeStatus.error,
      ));
      return;
    }
    final preparation = preparationResult.successOrNull!;

    emit(state.copyWith(
      status: DefaultPreparationSpareTimeStatus.success,
      preparation: preparation,
      spareTime: event.spareTime,
    ));
  }

  void _onSpareTimeIncreased(SpareTimeIncreased event,
      Emitter<DefaultPreparationSpareTimeFormState> emit) {
    final currentSpareTime = state.spareTime ?? Duration.zero;
    final newSpareTime = currentSpareTime + stepSize;

    emit(state.copyWith(
      spareTime: newSpareTime,
    ));
  }

  void _onSpareTimeDecreased(SpareTimeDecreased event,
      Emitter<DefaultPreparationSpareTimeFormState> emit) {
    final currentSpareTime = state.spareTime ?? Duration.zero;
    final newSpareTime = currentSpareTime - stepSize;

    if (newSpareTime >= lowerBound) {
      emit(state.copyWith(
        spareTime: newSpareTime,
      ));
    }
  }

  Future<void> _onFormSubmitted(FormSubmitted event,
      Emitter<DefaultPreparationSpareTimeFormState> emit) async {
    if (state.spareTime == null) {
      emit(state.copyWith(
        status: DefaultPreparationSpareTimeStatus.error,
      ));
      return;
    }

    emit(state.copyWith(
      status: DefaultPreparationSpareTimeStatus.loading,
    ));

    final prepUpdateResult =
        await _updateDefaultPreparationUseCase(event.preparation);
    if (prepUpdateResult.isFailure) {
      final failure = prepUpdateResult.failureOrNull!;
      addError(failure, failure.stackTrace);
      emit(state.copyWith(status: DefaultPreparationSpareTimeStatus.error));
      return;
    }

    final spareUpdateResult = await _updateSpareTimeUseCase(state.spareTime!);
    if (spareUpdateResult.isFailure) {
      final failure = spareUpdateResult.failureOrNull!;
      addError(failure, failure.stackTrace);
      emit(state.copyWith(status: DefaultPreparationSpareTimeStatus.error));
      return;
    }

    final loadUserResult = await _loadUserUseCase();
    if (loadUserResult.isFailure) {
      final failure = loadUserResult.failureOrNull!;
      addError(failure, failure.stackTrace);
      emit(state.copyWith(status: DefaultPreparationSpareTimeStatus.error));
      return;
    }

    emit(state.copyWith(
      status: DefaultPreparationSpareTimeStatus.success,
    ));
  }
}
