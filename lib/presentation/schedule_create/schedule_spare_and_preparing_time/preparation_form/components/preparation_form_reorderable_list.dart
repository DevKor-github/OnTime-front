import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_swipe_action_cell/core/cell.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/bloc/preparation_form_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/components/preparation_form_list_field.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/cubit/preparation_step_form_cubit.dart';

class _SwipeActionContent extends StatelessWidget {
  const _SwipeActionContent({
    required this.icon,
    required this.color,
  });

  final Widget icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color,
      ),
      padding: const EdgeInsets.all(18.0),
      child: icon,
    );
  }
}

class PreparationFormReorderableList extends StatelessWidget {
  const PreparationFormReorderableList({
    super.key,
    required this.preparationStepList,
    required this.onNameChanged,
    required this.onTimeChanged,
    required this.onReorder,
  });

  final List<PreparationStepFormState> preparationStepList;
  final Function(int index, String value) onNameChanged;
  final Function(int index, Duration value) onTimeChanged;
  final Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    Widget proxyDecorator(
        Widget child, int index, Animation<double> animation) {
      return AnimatedBuilder(
        animation: animation,
        builder: (BuildContext context, Widget? child) {
          return SizedBox(
            child: child,
          );
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
        itemCount: preparationStepList.length,
        itemBuilder: (context, index) {
          final step = preparationStepList[index];
          final theme = Theme.of(context);

          return SwipeActionCell(
            key: ValueKey<String>(step.id),
            backgroundColor: Colors.transparent,
            trailingActions: [
              SwipeAction(
                onTap: (controller) {
                  if (preparationStepList.length <= 1) return;
                  context.read<PreparationFormBloc>().add(
                        PreparationFormPreparationStepRemoved(
                          preparationStepId: step.id,
                        ),
                      );
                },
                color: Colors.transparent,
                content: _SwipeActionContent(
                  icon: const Icon(
                    Icons.delete,
                    color: Colors.white,
                    size: 24,
                  ),
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            child: PreparationFormListField(
              key: ValueKey<String>('field_${step.id}'),
              index: index,
              preparationStep: step,
              onNameChanged: (value) {
                onNameChanged(index, value);
              },
              onPreparationTimeChanged: (value) {
                onTimeChanged(index, value);
              },
            ),
          );
        },
        onReorder: (int oldIndex, int newIndex) {
          onReorder(oldIndex, newIndex);
        },
      ),
    );
  }
}
