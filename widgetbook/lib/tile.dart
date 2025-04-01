import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:on_time_front/presentation/shared/components/check_button.dart';
import 'package:on_time_front/presentation/shared/components/tile.dart';
import 'package:on_time_front/presentation/shared/theme/tile_style.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(name: 'Default', type: Tile)
Widget tile(BuildContext context) {
  final leading = context.knobs.boolean(label: 'Leading', initialValue: true);
  final trailing = context.knobs.boolean(label: 'Trailing', initialValue: true);

  return Tile(
    leading: leading
        ? SizedBox(
            height: 30,
            width: 30,
            child: CheckButton(isChecked: true, onPressed: () {}))
        : null,
    style: TileStyle(
      borderRadius: BorderRadius.circular(100),
      padding: const EdgeInsets.all(16.0) + const EdgeInsets.only(right: 17),
    ),
    trailing: trailing
        ? SvgPicture.asset(
            'drag_indicator.svg',
            package: 'assets',
            semanticsLabel: 'drag indicator',
            height: 14,
            width: 14,
            fit: BoxFit.contain,
          )
        : null,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 19.0),
      child: Center(
        child: Text(
          context.knobs.string(label: 'Text', initialValue: '샤워하기'),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    ),
  );
}
