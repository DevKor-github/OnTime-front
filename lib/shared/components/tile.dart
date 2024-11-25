import 'dart:ui';
import 'package:flutter/material.dart';

@immutable
class TileStyle extends ThemeExtension<TileStyle> {
  const TileStyle({
    this.backgroundColor,
    this.borderRadius,
    this.minimumSize,
    this.maximumSize,
    this.padding,
    this.margin,
  });

  /// the tile's background fill color.
  final Color? backgroundColor;

  final BorderRadius? borderRadius;

  /// The height of the tile.
  /// If null, the height will be determined by the child widget.
  final Size? minimumSize;

  /// The width of the tile.
  /// If null, the width will be determined by the child widget.
  final Size? maximumSize;

  /// The padding of the tile.
  final EdgeInsetsGeometry? padding;

  /// The margin of the tile.
  final EdgeInsetsGeometry? margin;

  @override
  ThemeExtension<TileStyle> copyWith(
      {Color? backgroundColor,
      BorderRadius? borderRadius,
      EdgeInsetsGeometry? padding,
      EdgeInsetsGeometry? margin,
      Size? minimumSize,
      Size? maximumSize}) {
    return TileStyle(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      borderRadius: borderRadius ?? this.borderRadius,
      minimumSize: minimumSize ?? this.minimumSize,
      maximumSize: maximumSize ?? this.maximumSize,
      padding: padding ?? this.padding,
      margin: margin ?? this.margin,
    );
  }

  @override
  ThemeExtension<TileStyle> lerp(
      covariant ThemeExtension<TileStyle>? other, double t) {
    if (other == null) return this;
    return TileStyle(
      backgroundColor:
          Color.lerp(backgroundColor, (other as TileStyle).backgroundColor, t)!,
      borderRadius: BorderRadius.lerp(borderRadius, other.borderRadius, t),
      minimumSize: Size.lerp(minimumSize, other.minimumSize, t),
      maximumSize: Size.lerp(maximumSize, other.maximumSize, t),
      padding: EdgeInsetsGeometry.lerp(padding, other.padding, t),
      margin: EdgeInsetsGeometry.lerp(margin, other.margin, t),
    );
  }
}

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
    final TileStyle? themeStyle = Theme.of(context).extension<TileStyle>();

    Color? backgroundColor =
        widgetStyle?.backgroundColor ?? themeStyle?.backgroundColor;
    BorderRadius? borderRadius =
        widgetStyle?.borderRadius ?? themeStyle?.borderRadius;
    Size? minimumSize = widgetStyle?.minimumSize ?? themeStyle?.minimumSize;
    Size? maximumSize = widgetStyle?.maximumSize ?? themeStyle?.maximumSize;
    EdgeInsetsGeometry? padding = widgetStyle?.padding ?? themeStyle?.padding;
    EdgeInsetsGeometry? margin = widgetStyle?.margin ?? themeStyle?.margin;

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
          child: Padding(
            padding: padding ?? const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    leading ?? SizedBox.shrink(),
                    child,
                  ],
                ),
                trailing ?? SizedBox.shrink(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
