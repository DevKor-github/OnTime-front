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

  final dragIndicatorSvg = SizedBox(
    height: 24,
    width: 24,
    child: Center(
      child: SvgPicture.asset(
        'assets/design/onboarding_drag.svg',
        semanticsLabel: 'drag indicator',
        height: 16,
        width: 18,
      ),
    ),
  );
  final PreparationStepOrderState preparationStepOrderState;
  final int index;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Tile(
      style: TileStyle(
        backgroundColor: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(9999),
        minimumSize: const Size(0, 62),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
          ),
        ),
      ),
      trailing: ReorderableDragStartListener(
        index: index,
        child: dragIndicatorSvg,
      ),
      child: Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            preparationStepOrderState.preparationName,
            style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
          ),
        ),
      ),
    );
  }
}
