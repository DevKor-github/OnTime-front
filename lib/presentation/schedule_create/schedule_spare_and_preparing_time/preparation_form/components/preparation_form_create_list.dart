import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/components/create_icon_button.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/bloc/preparation_form_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/components/preparation_form_list_field.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/components/preparation_form_reorderable_list.dart';

class PreparationFormCreateList extends StatelessWidget {
  const PreparationFormCreateList({
    super.key,
    required this.preparationNameState,
    required this.onNameChanged,
    required this.onCreationRequested,
    this.scrollController,
    this.stepKeyFor,
    this.nameFocusNodeFor,
  });

  final ScrollController? scrollController;
  final PreparationFormState preparationNameState;
  final Key Function(String stepId)? stepKeyFor;
  final FocusNode Function(String stepId)? nameFocusNodeFor;
  final void Function({required int index, required String value})
  onNameChanged;
  final VoidCallback onCreationRequested;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: scrollController,
      child: Column(
        children: [
          PreparationFormReorderableList(
            preparationStepList: preparationNameState.preparationStepList,
            showValidationErrors: preparationNameState.showValidationErrors,
            stepKeyFor: stepKeyFor,
            nameFocusNodeFor: nameFocusNodeFor,
            onNameChanged: (index, value) {
              onNameChanged(index: index, value: value);
            },
            onTimeChanged: (index, value) =>
                context.read<PreparationFormBloc>().add(
                  PreparationFormPreparationStepTimeChanged(
                    index: index,
                    preparationStepTime: value,
                  ),
                ),
            onReorder: (oldIndex, newIndex) =>
                context.read<PreparationFormBloc>().add(
                  PreparationFormPreparationStepOrderChanged(
                    oldIndex: oldIndex,
                    newIndex: newIndex,
                  ),
                ),
          ),
          preparationNameState.status == PreparationFormStatus.adding
              ? PreparationFormListField(
                  key:
                      stepKeyFor?.call(preparationNameState.draftStep!.id) ??
                      ValueKey<String>(
                        'draft_${preparationNameState.draftStep!.id}',
                      ),
                  isAdding: true,
                  showValidationErrors:
                      preparationNameState.showValidationErrors,
                  focusNode: nameFocusNodeFor?.call(
                    preparationNameState.draftStep!.id,
                  ),
                  preparationStep: preparationNameState.draftStep!,
                  onNameChanged: (value) {
                    context.read<PreparationFormBloc>().add(
                      PreparationFormDraftStepNameChanged(
                        preparationStepName: value,
                      ),
                    );
                  },
                  onPreparationTimeChanged: (value) {
                    context.read<PreparationFormBloc>().add(
                      PreparationFormDraftStepTimeChanged(
                        preparationStepTime: value,
                      ),
                    );
                  },
                )
              : SizedBox.shrink(),
          SizedBox(height: 28.0),
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
