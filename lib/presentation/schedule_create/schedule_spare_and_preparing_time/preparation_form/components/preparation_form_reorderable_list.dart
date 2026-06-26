import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_swipe_action_cell/core/controller.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/bloc/preparation_form_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/components/preparation_form_list_field.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/cubit/preparation_step_form_cubit.dart';

class PreparationFormReorderableList extends StatefulWidget {
  const PreparationFormReorderableList({
    super.key,
    required this.preparationStepList,
    required this.addingStepId,
    required this.showValidationErrors,
    required this.stepKeyFor,
    required this.nameFocusNodeFor,
    required this.onNameChanged,
    required this.onTimeChanged,
    required this.onReorder,
  });

  final List<PreparationStepFormState> preparationStepList;
  final String? addingStepId;
  final bool showValidationErrors;
  final Key Function(String stepId)? stepKeyFor;
  final FocusNode Function(String stepId)? nameFocusNodeFor;
  final Function(int index, String value) onNameChanged;
  final Function(int index, Duration value) onTimeChanged;
  final Function(int oldIndex, int newIndex) onReorder;

  @override
  State<PreparationFormReorderableList> createState() =>
      _PreparationFormReorderableListState();
}

class _PreparationFormReorderableListState
    extends State<PreparationFormReorderableList> {
  final SwipeActionController _swipeActionController = SwipeActionController();

  @override
  void dispose() {
    _swipeActionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget proxyDecorator(
      Widget child,
      int index,
      Animation<double> animation,
    ) {
      return AnimatedBuilder(
        animation: animation,
        builder: (BuildContext context, Widget? child) {
          return SizedBox(child: child);
        },
        child: child,
      );
    }

    return SingleChildScrollView(
      child: ReorderableListView.builder(
        buildDefaultDragHandles: false,
        proxyDecorator: proxyDecorator,
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: NeverScrollableScrollPhysics(),
        itemCount: widget.preparationStepList.length,
        itemBuilder: (context, index) {
          final step = widget.preparationStepList[index];

          return PreparationFormListField(
            key:
                widget.stepKeyFor?.call(step.id) ??
                ValueKey<String>('field_${step.id}'),
            index: index,
            isAdding: step.id == widget.addingStepId,
            canRemove: widget.preparationStepList.length > 1,
            showValidationErrors: widget.showValidationErrors,
            focusNode: widget.nameFocusNodeFor?.call(step.id),
            swipeActionController: _swipeActionController,
            preparationStep: step,
            onRemove: () {
              context.read<PreparationFormBloc>().add(
                PreparationFormPreparationStepRemoved(
                  preparationStepId: step.id,
                ),
              );
            },
            onNameChanged: (value) {
              widget.onNameChanged(index, value);
            },
            onNameFocusLost: (value) {
              context.read<PreparationFormBloc>().add(
                PreparationFormPreparationStepNameFocusLost(
                  index: index,
                  preparationStepName: value,
                ),
              );
            },
            onInteractionEnded: (value) {
              context.read<PreparationFormBloc>().add(
                PreparationFormPreparationStepInteractionEnded(
                  index: index,
                  preparationStepName: value,
                ),
              );
            },
            onPreparationTimeTapped: () {
              widget.onTimeChanged(index, step.preparationTime.value);
            },
            onPreparationTimeChanged: (value) {
              widget.onTimeChanged(index, value);
            },
          );
        },
        onReorderItem: (int oldIndex, int newIndex) {
          final legacyNewIndex = oldIndex < newIndex ? newIndex + 1 : newIndex;
          widget.onReorder(oldIndex, legacyNewIndex);
        },
      ),
    );
  }
}
