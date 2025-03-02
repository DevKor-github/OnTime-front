import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/components/create_icon_button.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/components/preparation_name_select_field.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/components/preparation_select_list.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/cubit/preparation_name/preparation_name_cubit.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/cubit/preparation_step_name/preparation_step_name_cubit.dart';

class PreparationCreateList extends StatelessWidget {
  const PreparationCreateList(
      {super.key,
      required this.preparationNameState,
      required this.onNameChanged,
      required this.onSelectionChanged,
      required this.onCreationRequested});

  final PreparationNameState preparationNameState;
  final void Function({required int index, required String value})
      onNameChanged;
  final void Function({required int index}) onSelectionChanged;
  final VoidCallback onCreationRequested;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          PreparationSelectList(
            preparationStepList: preparationNameState.preparationStepList,
            onNameChanged: (index, value) {
              onNameChanged(index: index, value: value);
            },
            onSelectionChanged: (index) {
              onSelectionChanged(index: index);
            },
          ),
          preparationNameState.status == PreparationNameStatus.adding
              ? BlocProvider<PreparationStepNameCubit>(
                  create: (context) => PreparationStepNameCubit(
                      PreparationStepNameState(),
                      preparationNameCubit:
                          context.read<PreparationNameCubit>()),
                  child: BlocBuilder<PreparationStepNameCubit,
                      PreparationStepNameState>(builder: (context, state) {
                    return PreparationNameSelectField(
                      isAdding: true,
                      preparationStep: state,
                      onNameChanged: (value) {
                        context
                            .read<PreparationStepNameCubit>()
                            .nameChanged(value);
                      },
                      onSelectionChanged: () {
                        context
                            .read<PreparationStepNameCubit>()
                            .selectionToggled();
                      },
                      onNameSaved: () {
                        context
                            .read<PreparationStepNameCubit>()
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
