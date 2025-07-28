import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/use-cases/get_default_preparation_use_case.dart';

part 'default_preparation_spare_time_form_event.dart';
part 'default_preparation_spare_time_form_state.dart';

@injectable
class DefaultPreparationSpareTimeFormBloc extends Bloc<
    DefaultPreparationSpareTimeFormEvent,
    DefaultPreparationSpareTimeFormState> {
  DefaultPreparationSpareTimeFormBloc(
    this._getDefaultPreparationUseCase,
  ) : super(DefaultPreparationSpareTimeFormState()) {
    on<FormEditRequested>(_onFormEditRequested);
  }

  final GetDefaultPreparationUseCase _getDefaultPreparationUseCase;

  Future<void> _onFormEditRequested(FormEditRequested event,
      Emitter<DefaultPreparationSpareTimeFormState> emit) async {
    emit(state.copyWith(
      status: DefaultPreparationSpareTimeStatus.loading,
    ));

    final preparation = await _getDefaultPreparationUseCase();

    emit(state.copyWith(
      status: DefaultPreparationSpareTimeStatus.success,
      preparation: preparation,
      spareTime: event.spareTime,
    ));
  }
}
