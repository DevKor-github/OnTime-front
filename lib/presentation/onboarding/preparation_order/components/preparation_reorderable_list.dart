import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/onboarding/preparation_order/components/reorderable_tile.dart';
import 'package:on_time_front/presentation/onboarding/preparation_order/cubit/preparation_order_cubit.dart';

class PreparationReorderableList extends StatelessWidget {
  const PreparationReorderableList(
      {super.key,
      required this.preparationOrderingList,
      required this.onReorder});

  final List<PreparationStepOrderState> preparationOrderingList;
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
        physics: NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        proxyDecorator: proxyDecorator,
        itemCount: preparationOrderingList.length,
        itemBuilder: (context, index) => Padding(
          key: ValueKey<String>(preparationOrderingList[index].preparationId),
          padding: const EdgeInsets.only(bottom: 8.0),
          child: ReorderableTile(
              preparationStepOrderState: preparationOrderingList[index],
              index: index),
        ),
        onReorder: onReorder,
      ),
    );
  }
}
