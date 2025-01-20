import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/shared/components/check_button.dart';
import 'package:on_time_front/presentation/shared/components/tile.dart';
import 'package:on_time_front/presentation/shared/theme/tile_style.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(name: 'Default', type: Tile)
Widget buildTileUseCase(BuildContext context) {
  final leading = context.knobs.boolean(label: 'Leading', initialValue: true);

  final isChecked = context.knobs.boolean(label: 'Checked', initialValue: true);

  return Center(
    child: Padding(
      padding: const EdgeInsets.all(8.0),
      child: Tile(
        leading: leading
            ? CheckButton(isChecked: isChecked, onPressed: () {})
            : null,
        style: TileStyle(
          borderRadius: BorderRadius.circular(100),
          margin: const EdgeInsets.all(8.0),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 19.0),
          child:
              Text(context.knobs.string(label: 'Text', initialValue: '샤워하기')),
        ),
      ),
    ),
  );
}
