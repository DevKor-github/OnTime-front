import 'package:flutter/material.dart';
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Tile(
      style: TileStyle(
        backgroundColor: Color(0xFFE6E9F9),
        padding: EdgeInsets.all(18.0) + EdgeInsets.only(right: 15),
      ),
      leading: Container(
        height: 22,
        width: 22,
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Center(
          child: Text(
            (index + 1).toString(),
            style: TextStyle(
              color: colorScheme.surface,
              fontSize: 10.48,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ),
      ),
      trailing: ReorderableDragStartListener(
        index: index,
        child: dragIndicatorSvg,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Text(
          preparationStepOrderState.preparationName,
          style: textTheme.bodyLarge?.copyWith(
            color: colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}
