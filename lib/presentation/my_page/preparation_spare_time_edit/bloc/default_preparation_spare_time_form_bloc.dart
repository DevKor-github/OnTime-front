import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/validation/local_input_limits.dart';
import 'package:on_time_front/domain/entities/default_preferences.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/use-cases/default_preferences_workflow.dart';

part 'default_preparation_spare_time_form_event.dart';
part 'default_preparation_spare_time_form_state.dart';

@injectable
class DefaultPreparationSpareTimeFormBloc
    extends
        Bloc<
          DefaultPreparationSpareTimeFormEvent,
          DefaultPreparationSpareTimeFormState
        > {
  DefaultPreparationSpareTimeFormBloc(this._workflow)
    : super(const DefaultPreparationSpareTimeFormState()) {
    on<FormEditRequested>(_load);
    on<SpareTimeIncreased>((event, emit) => _changeSpare(5, emit));
    on<SpareTimeDecreased>((event, emit) => _changeSpare(-5, emit));
    on<FormSubmitted>(_save);
    on<FormFollowUpRetried>(_retry);
  }
  final DefaultPreferencesWorkflow _workflow;
  Object _owner = Object();
  bool _busy = false;
  Object get formOwner => _owner;
  bool ownsForm(Object owner) => !isClosed && identical(owner, _owner);
  bool get current =>
      state.baseline != null &&
      _workflow.isGenerationCurrent(state.baseline!.generation);

  Future<void> _load(
    FormEditRequested event,
    Emitter<DefaultPreparationSpareTimeFormState> emit,
  ) async {
    if (_busy) return;
    final owner = _owner = Object();
    _busy = true;
    emit(state.copyWith(status: DefaultPreparationSpareTimeStatus.loading));
    try {
      final snapshot = await _workflow.read();
      if (!ownsForm(owner) ||
          !_workflow.isGenerationCurrent(snapshot.generation)) {
        return;
      }
      emit(
        DefaultPreparationSpareTimeFormState(
          status: DefaultPreparationSpareTimeStatus.success,
          preparation: snapshot.preparation,
          spareTime: snapshot.spareTime,
          baseline: snapshot,
          editorVersion: state.editorVersion + 1,
        ),
      );
    } catch (_) {
      if (ownsForm(owner)) {
        emit(
          state.copyWith(
            status: DefaultPreparationSpareTimeStatus.error,
            failure: state.failure ?? DefaultPreferencesFailure.failed,
          ),
        );
      }
    } finally {
      if (ownsForm(owner)) _busy = false;
    }
  }

  void _changeSpare(
    int delta,
    Emitter<DefaultPreparationSpareTimeFormState> emit,
  ) {
    if (_busy || !state.canEdit) return;
    final minutes = state.spareTime!.inMinutes + delta;
    if (minutes < 0 || minutes > LocalInputLimits.maxMinuteValue) return;
    emit(state.copyWith(spareTime: Duration(minutes: minutes)));
  }

  Future<void> _save(
    FormSubmitted event,
    Emitter<DefaultPreparationSpareTimeFormState> emit,
  ) async {
    if (_busy || !state.canSubmit) return;
    final owner = _owner;
    _busy = true;
    final input = DefaultPreferencesSubmission(
      baseline: state.baseline!,
      preparation: event.preparation,
      spareTime: state.spareTime!,
    );
    emit(
      state.copyWith(
        status: DefaultPreparationSpareTimeStatus.submitting,
        preparation: input.preparation,
        clearFailure: true,
      ),
    );
    try {
      final receipt = await _workflow.save(input);
      if (!ownsForm(owner)) return;
      _accept(receipt, emit);
    } on DefaultPreferencesRejected catch (error) {
      if (ownsForm(owner)) {
        emit(
          state.copyWith(
            status: DefaultPreparationSpareTimeStatus.error,
            failure: error.failure,
          ),
        );
      }
    } catch (_) {
      if (ownsForm(owner)) {
        emit(
          state.copyWith(
            status: DefaultPreparationSpareTimeStatus.error,
            failure: DefaultPreferencesFailure.failed,
          ),
        );
      }
    } finally {
      if (ownsForm(owner)) _busy = false;
    }
  }

  Future<void> _retry(
    FormFollowUpRetried event,
    Emitter<DefaultPreparationSpareTimeFormState> emit,
  ) async {
    final receipt = state.receipt;
    if (_busy || receipt == null) return;
    final owner = _owner;
    _busy = true;
    emit(state.copyWith(status: DefaultPreparationSpareTimeStatus.submitting));
    try {
      final result = await _workflow.retry(receipt);
      if (ownsForm(owner)) _accept(result, emit);
    } finally {
      if (ownsForm(owner)) _busy = false;
    }
  }

  void _accept(
    DefaultPreferencesSaveReceipt receipt,
    Emitter<DefaultPreparationSpareTimeFormState> emit,
  ) {
    final replaced =
        receipt.superseded || receipt.generation != _workflow.generation;
    final current = _workflow.isGenerationCurrent(receipt.generation);
    final result = receipt.withFollowUp(
      reloadPending: receipt.reloadPending,
      deliveryPending: receipt.deliveryPending,
      superseded: replaced,
      authorityPending: !replaced && (receipt.authorityPending || !current),
    );
    emit(
      state.copyWith(
        status: result.complete
            ? DefaultPreparationSpareTimeStatus.submitted
            : DefaultPreparationSpareTimeStatus.followUpPending,
        receipt: result,
        failure: replaced ? DefaultPreferencesFailure.unavailable : null,
        clearFailure: !replaced,
      ),
    );
  }
}
