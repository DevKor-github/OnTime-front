import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/bloc/preparation_form_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/components/preparation_form_list_field.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/cubit/preparation_step_form_cubit.dart';

class PreparationFormReorderableListDismissible extends StatelessWidget {
  const PreparationFormReorderableListDismissible({
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
          return Dismissible(
            key: ValueKey<String>(
                'dismissible_${preparationStepList[index].id}'),
            direction: DismissDirection.endToStart,
            background: Container(
              height: double.infinity,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20.0),
              color: Colors.red,
              child: const Icon(
                Icons.delete,
                color: Colors.white,
                size: 24,
              ),
            ),
            confirmDismiss: (direction) async {
              if (preparationStepList.length <= 1) {
                return false;
              }
              return direction == DismissDirection.endToStart;
            },
            onDismissed: (direction) {
              if (direction == DismissDirection.endToStart) {
                context.read<PreparationFormBloc>().add(
                      PreparationFormPreparationStepRemoved(
                        preparationStepId: preparationStepList[index].id,
                      ),
                    );
              }
            },
            child: PreparationFormListField(
              key: ValueKey<String>(preparationStepList[index].id),
              index: index,
              preparationStep: preparationStepList[index],
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
