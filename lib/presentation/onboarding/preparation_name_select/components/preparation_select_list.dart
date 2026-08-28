import 'package:flutter/widgets.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/components/preparation_name_select_field.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/cubit/preparation_step_name/preparation_step_name_cubit.dart';

class PreparationSelectList extends StatelessWidget {
  const PreparationSelectList({
    super.key,
    required this.preparationStepList,
    required this.onNameChanged,
    required this.onSelectionChanged,
  });

  final List<PreparationStepNameState> preparationStepList;
  final Function(int index, String value) onNameChanged;
  final Function(int index) onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: NeverScrollableScrollPhysics(),
      itemCount: preparationStepList.length,
      itemBuilder: (context, index) {
        return PreparationNameSelectField(
          preparationStep: preparationStepList[index],
          onNameChanged: (value) {
            onNameChanged(index, value);
          },
          onSelectionChanged: () {
            onSelectionChanged(index);
          },
        );
      },
    );
  }
}
