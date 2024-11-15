import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:on_time_front/shared/components/tile.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(name: 'Default', type: Tile)
Widget buildTileUseCase(BuildContext context) {
  final leading = context.knobs.boolean(label: 'Leading', initialValue: true);
  const checkSvg = 'assets/check.svg';
  final Widget svg = SvgPicture.asset(
    checkSvg,
    semanticsLabel: 'check',
  );

  return Center(
    child: Padding(
      padding: const EdgeInsets.all(8.0),
      child: Tile(
        leading: leading
            ? CircleAvatar(
                backgroundColor: const Color.fromARGB(255, 0, 202, 120),
                child: svg)
            : null,
        style: TileStyle(
          borderRadius: BorderRadius.circular(32),
          height: 30,
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
