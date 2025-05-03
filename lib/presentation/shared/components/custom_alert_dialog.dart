import 'dart:ui';

import 'package:flutter/material.dart';

class CustomAlertDialog extends StatelessWidget {
  const CustomAlertDialog({
    super.key,
    this.title,
    this.titleTextStyle,
    this.content,
    this.contentTextStyle,
    this.actions,
    this.actionsAlignment,
    this.actionsOverflowAlignment,
    this.actionsOverflowDirection,
    this.actionsOverflowButtonSpacing,
    this.buttonPadding,
    this.backgroundColor,
    this.elevation,
    this.shadowColor,
    this.surfaceTintColor,
    this.semanticLabel,
    this.innerPadding,
    this.insetPadding,
    this.clipBehavior,
    this.shape,
    this.alignment,
    this.scrollable = false,
    this.titleContentSpacing,
    this.contentActionsSpacing,
  })  : _defaultTitleTextAlign = TextAlign.start,
        _defualtContentTextAlign = TextAlign.start;

  final Widget? title;

  final TextStyle? titleTextStyle;

  final Widget? content;

  final TextStyle? contentTextStyle;

  final List<Widget>? actions;

  final MainAxisAlignment? actionsAlignment;

  final OverflowBarAlignment? actionsOverflowAlignment;

  final VerticalDirection? actionsOverflowDirection;

  final double? actionsOverflowButtonSpacing;

  final EdgeInsetsGeometry? buttonPadding;

  final Color? backgroundColor;

  final double? elevation;

  final Color? shadowColor;

  final Color? surfaceTintColor;

  final String? semanticLabel;

  final EdgeInsets? innerPadding;

  final EdgeInsets? insetPadding;

  final Clip? clipBehavior;
  final ShapeBorder? shape;

  final AlignmentGeometry? alignment;

  final bool scrollable;

  final double? titleContentSpacing;

  final double? contentActionsSpacing;

  final TextAlign _defaultTitleTextAlign;
  final TextAlign _defualtContentTextAlign;

  const CustomAlertDialog.error({
    super.key,
    this.title,
    this.titleTextStyle,
    this.content,
    this.contentTextStyle,
    this.actions,
    this.actionsAlignment,
    this.actionsOverflowAlignment,
    this.actionsOverflowDirection,
    this.actionsOverflowButtonSpacing,
    this.buttonPadding,
    this.backgroundColor,
    this.elevation,
    this.shadowColor,
    this.surfaceTintColor,
    this.semanticLabel,
    this.innerPadding,
    this.insetPadding,
    this.clipBehavior,
    this.shape,
    this.alignment = Alignment.center,
    this.scrollable = false,
    this.titleContentSpacing = 6.0,
    this.contentActionsSpacing = 16.0,
  })  : _defaultTitleTextAlign = TextAlign.center,
        _defualtContentTextAlign = TextAlign.center;

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMaterialLocalizations(context));
    final ThemeData theme = Theme.of(context);

    final DialogThemeData dialogTheme = DialogTheme.of(context);
    final DialogThemeData defaults = _DialogDefaults(context);

    String? label = semanticLabel;
    switch (theme.platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        break;
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        label ??= MaterialLocalizations.of(context).alertDialogLabel;
    }

    final double paddingScaleFactor =
        _scalePadding(MediaQuery.textScalerOf(context).scale(14.0) / 14.0);

    Widget? titleWidget;
    Widget? contentWidget;
    Widget? actionsWidget;

    if (title != null) {
      titleWidget = DefaultTextStyle(
        style: titleTextStyle ??
            dialogTheme.titleTextStyle ??
            defaults.titleTextStyle!,
        textAlign: _defaultTitleTextAlign,
        child: Semantics(
          namesRoute: label == null && theme.platform != TargetPlatform.iOS,
          container: true,
          child: title,
        ),
      );
    }

    if (content != null) {
      contentWidget = DefaultTextStyle(
        style: contentTextStyle ??
            dialogTheme.contentTextStyle ??
            defaults.contentTextStyle!,
        textAlign: _defualtContentTextAlign,
        child: Semantics(
          container: true,
          explicitChildNodes: true,
          child: content,
        ),
      );
    }

    if (actions != null) {
      final double spacing = (buttonPadding?.horizontal ?? 16) / 2;
      actionsWidget = OverflowBar(
        alignment: actionsAlignment ?? MainAxisAlignment.end,
        spacing: spacing,
        overflowAlignment: actionsOverflowAlignment ?? OverflowBarAlignment.end,
        overflowDirection: actionsOverflowDirection ?? VerticalDirection.down,
        overflowSpacing: actionsOverflowButtonSpacing ?? 0,
        children: actions!,
      );
    }

    List<Widget> columnChildren = [];
    final SizedBox defaultTitleContentSpacing = const SizedBox(height: 8.0);
    final SizedBox defaultContentActionsSpacing = const SizedBox(height: 18.0);
    final SizedBox effectiveTitleContentSpacing = titleContentSpacing == null
        ? defaultTitleContentSpacing
        : SizedBox(
            height: titleContentSpacing,
          );
    final SizedBox effectiveContentActionsSpacing =
        contentActionsSpacing == null
            ? defaultContentActionsSpacing
            : SizedBox(
                height: contentActionsSpacing,
              );
    if (title != null) columnChildren.add(titleWidget!);
    if (title != null && content != null) {
      columnChildren.add(effectiveTitleContentSpacing);
    }
    if (content != null) columnChildren.add(contentWidget!);
    if ((title != null || content != null) && actions != null) {
      columnChildren.add(
        effectiveContentActionsSpacing,
      );
    }
    if (actions != null) columnChildren.add(actionsWidget!);

    final EdgeInsets defaultInnerPadding = EdgeInsets.only(
      left: 20.0,
      top: 20.0,
      right: 18.0,
      bottom: 18.0,
    );
    final EdgeInsets effectiveInnerPadding =
        innerPadding ?? defaultInnerPadding;
    Widget dialogChild = IntrinsicWidth(
      child: Padding(
        padding: effectiveInnerPadding * paddingScaleFactor,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: columnChildren,
        ),
      ),
    );

    if (label != null) {
      dialogChild = Semantics(
        scopesRoute: true,
        explicitChildNodes: true,
        namesRoute: true,
        label: label,
        child: dialogChild,
      );
    }

    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      elevation: elevation,
      shadowColor: shadowColor,
      surfaceTintColor: surfaceTintColor,
      insetPadding: insetPadding,
      clipBehavior: clipBehavior,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: alignment,
      child: dialogChild,
    );
  }
}

double _scalePadding(double textScaleFactor) {
  final double clampedTextScaleFactor = clampDouble(textScaleFactor, 1.0, 2.0);
  return lerpDouble(1.0, 1.0 / 3.0, clampedTextScaleFactor - 1.0)!;
}

class _DialogDefaults extends DialogThemeData {
  _DialogDefaults(this.context)
      : super(
          alignment: Alignment.center,
          elevation: 6.0,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(28.0))),
          clipBehavior: Clip.none,
        );

  final BuildContext context;
  late final ColorScheme _colors = Theme.of(context).colorScheme;
  late final TextTheme _textTheme = Theme.of(context).textTheme;

  @override
  Color? get iconColor => _colors.secondary;

  @override
  Color? get backgroundColor => _colors.surfaceContainerHigh;

  @override
  Color? get shadowColor => Colors.transparent;

  @override
  Color? get surfaceTintColor => Colors.transparent;

  @override
  TextStyle? get titleTextStyle => _textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
      );

  @override
  TextStyle? get contentTextStyle => _textTheme.bodyMedium;

  @override
  EdgeInsetsGeometry? get actionsPadding =>
      const EdgeInsets.only(left: 0.0, right: 0.0, bottom: 0.0);
}
