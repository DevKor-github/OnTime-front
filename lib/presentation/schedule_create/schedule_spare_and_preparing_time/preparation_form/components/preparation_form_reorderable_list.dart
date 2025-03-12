import 'package:flutter/widgets.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/components/preparation_form_list_field.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/cubit/preparation_step_form_cubit.dart';

class PreparationFormReorderableList extends StatelessWidget {
  const PreparationFormReorderableList({
    super.key,
    required this.preparationStepList,
    required this.onNameChanged,
  });

  final List<PreparationStepFormState> preparationStepList;
  final Function(int index, String value) onNameChanged;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: NeverScrollableScrollPhysics(),
      itemCount: preparationStepList.length,
      itemBuilder: (context, index) {
        return PreparationFormListField(
          preparationStep: preparationStepList[index],
          onNameChanged: (value) {
            onNameChanged(index, value);
          },
        );
      },
    );
  }
}
