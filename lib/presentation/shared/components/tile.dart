import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/shared/theme/tile_style.dart';

class Tile extends StatelessWidget {
  const Tile(
      {super.key,
      this.statesController,
      this.style,
      this.leading,
      this.trailing,
      required this.child});

  final WidgetStatesController? statesController;

  final TileStyle? style;

  final Widget? leading;

  final Widget child;

  final Widget? trailing;

  bool get enabled => true;
  @override
  Widget build(BuildContext context) {
    final TileStyle? widgetStyle = style;
    final TileStyle themeStyle = Theme.of(context).extension<TileStyle>()!;

    Color? backgroundColor =
        widgetStyle?.backgroundColor ?? themeStyle.backgroundColor;
    BorderRadius? borderRadius =
        widgetStyle?.borderRadius ?? themeStyle.borderRadius;
    Size? minimumSize = widgetStyle?.minimumSize ?? themeStyle.minimumSize;
    Size? maximumSize = widgetStyle?.maximumSize ?? themeStyle.maximumSize;
    EdgeInsetsGeometry? padding = widgetStyle?.padding ?? themeStyle.padding;
    EdgeInsetsGeometry? margin = widgetStyle?.margin ?? themeStyle.margin;

    return Padding(
      padding: margin ?? const EdgeInsets.all(0),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: minimumSize?.height ?? 0,
          maxHeight: maximumSize?.height ?? double.infinity,
          minWidth: minimumSize?.width ?? 0,
          maxWidth: maximumSize?.width ?? double.infinity,
        ),
        child: Material(
          borderRadius: borderRadius ?? BorderRadius.zero,
          color: backgroundColor,
          textStyle: Theme.of(context).textTheme.bodyMedium,
          child: Padding(
            padding: padding ?? const EdgeInsets.all(8),
            child: IntrinsicHeight(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        leading ?? SizedBox.shrink(),
                        child,
                      ],
                    ),
                  ),
                  trailing ?? SizedBox.shrink(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
