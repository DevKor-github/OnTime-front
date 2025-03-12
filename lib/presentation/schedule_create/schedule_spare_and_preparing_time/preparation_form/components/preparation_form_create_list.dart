import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/components/create_icon_button.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/cubit/preparation_name/preparation_name_cubit.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/preparation_form/preparation_form_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/components/preparation_form_list_field.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/components/preparation_form_reorderable_list.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/cubit/preparation_step_form_cubit.dart';

class PreparationFormCreateList extends StatelessWidget {
  const PreparationFormCreateList(
      {super.key,
      required this.preparationNameState,
      required this.onNameChanged,
      required this.onSelectionChanged,
      required this.onCreationRequested});

  final PreparationFormState preparationNameState;
  final void Function({required int index, required String value})
      onNameChanged;
  final void Function({required int index}) onSelectionChanged;
  final VoidCallback onCreationRequested;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          PreparationFormReorderableList(
            preparationStepList: preparationNameState.preparationStepList,
            onNameChanged: (index, value) {
              onNameChanged(index: index, value: value);
            },
          ),
          preparationNameState.status == PreparationFormStatus.adding
              ? BlocProvider<PreparationStepFormCubit>(
                  create: (context) => PreparationStepFormCubit(
                      PreparationStepFormState(),
                      preparationFormBloc: context.read<PreparationFormBloc>()),
                  child: BlocBuilder<PreparationStepFormCubit,
                      PreparationStepFormState>(builder: (context, state) {
                    return PreparationFormListField(
                      isAdding: true,
                      preparationStep: state,
                      onNameChanged: (value) {
                        context
                            .read<PreparationStepFormCubit>()
                            .nameChanged(value);
                      },
                      onNameSaved: () {
                        context
                            .read<PreparationStepFormCubit>()
                            .preparationStepSaved();
                      },
                    );
                  }),
                )
              : SizedBox.shrink(),
          SizedBox(
            height: 28.0,
          ),
          Center(
            child: SizedBox(
              height: 30,
              width: 30,
              child: CreateIconButton(onCreationRequested: onCreationRequested),
            ),
          ),
          SizedBox(height: 56.0),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
    );
  }
}
