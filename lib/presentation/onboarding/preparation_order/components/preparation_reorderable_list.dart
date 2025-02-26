import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:on_time_front/presentation/onboarding/preparation_order/cubit/preparation_order_cubit.dart';
import 'package:on_time_front/presentation/shared/components/tile.dart';
import 'package:on_time_front/presentation/shared/theme/tile_style.dart';

class PreparationReorderableList extends StatelessWidget {
  PreparationReorderableList(
      {super.key,
      required this.preparationOrderingList,
      required this.onReorder});

  final List<PreparationStepOrderState> preparationOrderingList;
  final Function(int oldIndex, int newIndex) onReorder;

  final Widget dragIndicatorSvg = SvgPicture.asset(
    'assets/drag_indicator.svg',
    semanticsLabel: 'drag indicator',
    height: 14,
    width: 14,
    fit: BoxFit.contain,
  );

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
          child: Tile(
            style: TileStyle(
              backgroundColor: Color(0xFFE6E9F9),
            ),
            trailing: ReorderableDragStartListener(
              index: index,
              child: dragIndicatorSvg,
            ),
            child: Text(
              preparationOrderingList[index].preparationName,
            ),
          ),
        ),
        onReorder: onReorder,
      ),
    );
  }
}
