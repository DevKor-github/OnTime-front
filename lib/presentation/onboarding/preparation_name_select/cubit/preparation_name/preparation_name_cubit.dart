import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/cubit/preparation_step_name/preparation_step_name_cubit.dart';

part 'preparation_name_state.dart';

class PreparationNameCubit extends Cubit<PreparationNameState> {
  PreparationNameCubit() : super(PreparationNameState());
}
