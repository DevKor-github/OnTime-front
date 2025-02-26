import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/components/preparation_name_select_field.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/cubit/preparation_name/preparation_name_cubit.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/cubit/preparation_step_name/preparation_step_name_cubit.dart';

class PreparationSelectList extends StatelessWidget {
  const PreparationSelectList({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return BlocBuilder<PreparationNameCubit, PreparationNameState>(
        builder: (context, state) {
      return SingleChildScrollView(
        child: Column(
          children: [
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: state.preparationStepList.length,
              itemBuilder: (context, index) {
                return PreparationNameSelectField(
                  preparationStep: state.preparationStepList[index],
                  onNameChanged: (value) {
                    context
                        .read<PreparationNameCubit>()
                        .preparationStepNameChanged(index: index, value: value);
                  },
                  onSelectionChanged: () {
                    context
                        .read<PreparationNameCubit>()
                        .preparationStepSelectionChanged(index: index);
                  },
                );
              },
            ),
            state.status == PreparationNameStatus.adding
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
                child: IconButton(
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all<Color>(
                        colorScheme.primaryContainer),
                  ),
                  onPressed: () {
                    context
                        .read<PreparationNameCubit>()
                        .preparationStepCreationRequested();
                  },
                  color: colorScheme.onPrimary,
                  icon: Icon(Icons.add),
                  padding: EdgeInsets.zero,
                  iconSize: 30.0,
                ),
              ),
            ),
            SizedBox(height: 56.0),
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
          ],
        ),
      );
    });
  }
}
