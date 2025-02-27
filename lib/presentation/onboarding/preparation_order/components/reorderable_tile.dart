import 'package:flutter/widgets.dart';
import 'package:flutter_svg/svg.dart';
import 'package:on_time_front/presentation/onboarding/preparation_order/cubit/preparation_order_cubit.dart';
import 'package:on_time_front/presentation/shared/components/tile.dart';
import 'package:on_time_front/presentation/shared/theme/tile_style.dart';

class ReorderableTile extends StatelessWidget {
  ReorderableTile({
    super.key,
    required this.preparationStepOrderState,
    required this.index,
  });

  final dragIndicatorSvg = SvgPicture.asset(
    'assets/drag_indicator.svg',
    semanticsLabel: 'drag indicator',
    height: 14,
    width: 14,
    fit: BoxFit.contain,
  );
  final PreparationStepOrderState preparationStepOrderState;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Tile(
      style: TileStyle(
        backgroundColor: Color(0xFFE6E9F9),
      ),
      trailing: ReorderableDragStartListener(
        index: index,
        child: dragIndicatorSvg,
      ),
      child: Text(
        preparationStepOrderState.preparationName,
      ),
    );
  }
}
