import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:on_time_front/presentation/onboarding/preparation_time/components/preparation_time_tile.dart';
import 'package:on_time_front/presentation/onboarding/preparation_time/cubit/preparation_time_cubit.dart';

class PreparationTimeInputFieldList extends StatefulWidget {
  const PreparationTimeInputFieldList({
    super.key,
    required this.preparationTimeList,
    required this.onPreparationTimeChanged,
  });

  final List<PreparationStepTimeState> preparationTimeList;
  final Function(int index, Duration value) onPreparationTimeChanged;

  @override
  State<PreparationTimeInputFieldList> createState() =>
      _PreparationTimeInputFieldListState();
}

class _PreparationTimeInputFieldListState
    extends State<PreparationTimeInputFieldList> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: ListView.builder(
        physics: NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: widget.preparationTimeList.length,
        itemBuilder: (context, index) {
          final value = widget.preparationTimeList[index];
          return PreparationTimeTile(
              value: value,
              index: index,
              onPreparationTimeChanged: widget.onPreparationTimeChanged);
        },
      ),
    );
  }
}
