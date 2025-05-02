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

  /// The (optional) title of the dialog is displayed in a large font at the top
  /// of the dialog, below the (optional) [icon].
  ///
  /// Typically a [Text] widget.
  final Widget? title;

  /// Style for the text in the [title] of this [CustomAlertDialog].
  ///
  /// If null, [DialogThemeData.titleTextStyle] is used. If that's null, defaults to
  /// [TextTheme.headlineSmall] of [ThemeData.textTheme] if
  /// [ThemeData.useMaterial3] is true, [TextTheme.titleLarge] otherwise.
  final TextStyle? titleTextStyle;

  /// The (optional) content of the dialog is displayed in the center of the
  /// dialog in a lighter font.
  ///
  /// Typically this is a [SingleChildScrollView] that contains the dialog's
  /// message. As noted in the [CustomAlertDialog] documentation, it's important
  /// to use a [SingleChildScrollView] if there's any risk that the content
  /// will not fit, as the contents will otherwise overflow the dialog.
  ///
  /// The [content] must support reporting its intrinsic dimensions. In
  /// particular, [ListView], [GridView], and [CustomScrollView] cannot be used
  /// here unless they are first wrapped in a widget that itself can report
  /// intrinsic dimensions, such as a [SizedBox].
  final Widget? content;

  /// Style for the text in the [content] of this [CustomAlertDialog].
  ///
  /// If null, [DialogThemeData.contentTextStyle] is used. If that's null, defaults
  /// to [TextTheme.bodyMedium] of [ThemeData.textTheme]
  final TextStyle? contentTextStyle;

  /// The (optional) set of actions that are displayed at the bottom of the
  /// dialog with an [OverflowBar].
  ///
  /// Typically this is a list of [TextButton] widgets. It is recommended to
  /// set the [Text.textAlign] to [TextAlign.end] for the [Text] within the
  /// [TextButton], so that buttons whose labels wrap to an extra line align
  /// with the overall [OverflowBar]'s alignment within the dialog.
  ///
  /// If the [title] is not null but the [content] _is_ null, then an extra 20
  /// pixels of padding is added above the [OverflowBar] to separate the [title]
  /// from the [actions].
  final List<Widget>? actions;

  /// Defines the horizontal layout of the [actions] according to the same
  /// rules as for [Row.mainAxisAlignment].
  ///
  /// This parameter is passed along to the dialog's [OverflowBar].
  ///
  /// If this parameter is null (the default) then [MainAxisAlignment.end]
  /// is used.
  final MainAxisAlignment? actionsAlignment;

  /// The horizontal alignment of [actions] within the vertical
  /// "overflow" layout.
  ///
  /// If the dialog's [actions] do not fit into a single row, then they
  /// are arranged in a column. This parameter controls the horizontal
  /// alignment of widgets in the case of an overflow.
  ///
  /// If this parameter is null (the default) then [OverflowBarAlignment.end]
  /// is used.
  ///
  /// See also:
  ///
  /// * [OverflowBar], which [actions] configures to lay itself out.
  final OverflowBarAlignment? actionsOverflowAlignment;

  /// The vertical direction of [actions] if the children overflow
  /// horizontally.
  ///
  /// If the dialog's [actions] do not fit into a single row, then they
  /// are arranged in a column. The first action is at the top of the
  /// column if this property is set to [VerticalDirection.down], since it
  /// "starts" at the top and "ends" at the bottom. On the other hand,
  /// the first action will be at the bottom of the column if this
  /// property is set to [VerticalDirection.up], since it "starts" at the
  /// bottom and "ends" at the top.
  ///
  /// See also:
  ///
  /// * [OverflowBar], which [actions] configures to lay itself out.
  final VerticalDirection? actionsOverflowDirection;

  /// The spacing between [actions] when the [OverflowBar] switches to a column
  /// layout because the actions don't fit horizontally.
  ///
  /// If the widgets in [actions] do not fit into a single row, they are
  /// arranged into a column. This parameter provides additional vertical space
  /// between buttons when it does overflow.
  ///
  /// The button spacing may appear to be more than the value provided. This is
  /// because most buttons adhere to the [MaterialTapTargetSize] of 48px. So,
  /// even though a button might visually be 36px in height, it might still take
  /// up to 48px vertically.
  ///
  /// If null then no spacing will be added in between buttons in an overflow
  /// state.
  final double? actionsOverflowButtonSpacing;

  /// The padding that surrounds each button in [actions].
  ///
  /// If this property is null, then it will default to
  /// 8.0 logical pixels on the left and right.
  final EdgeInsetsGeometry? buttonPadding;

  /// {@macro flutter.material.dialog.backgroundColor}
  final Color? backgroundColor;

  /// {@macro flutter.material.dialog.elevation}
  final double? elevation;

  /// {@macro flutter.material.dialog.shadowColor}
  final Color? shadowColor;

  /// {@macro flutter.material.dialog.surfaceTintColor}
  final Color? surfaceTintColor;

  /// The semantic label of the dialog used by accessibility frameworks to
  /// announce screen transitions when the dialog is opened and closed.
  ///
  /// In iOS, if this label is not provided, a semantic label will be inferred
  /// from the [title] if it is not null.
  ///
  /// In Android, if this label is not provided, the dialog will use the
  /// [MaterialLocalizations.alertDialogLabel] as its label.
  ///
  /// See also:
  ///
  ///  * [SemanticsConfiguration.namesRoute], for a description of how this
  ///    value is used.
  final String? semanticLabel;

  /// The padding that surrounds the dialog.
  ///
  /// This is different from [insetPadding], which defines the padding
  /// between the dialog and the screen.
  ///
  /// If this property is null, then it will default to
  /// 20.0 logical pixels on the left and right and 18.0 logical pixels on
  /// the top and bottom.
  final EdgeInsets? innerPadding;

  /// {@macro flutter.material.dialog.insetPadding}
  final EdgeInsets? insetPadding;

  /// {@macro flutter.material.dialog.clipBehavior}
  final Clip? clipBehavior;

  /// {@macro flutter.material.dialog.shape}
  final ShapeBorder? shape;

  /// {@macro flutter.material.dialog.alignment}
  final AlignmentGeometry? alignment;

  /// Determines whether the [title] and [content] widgets are wrapped in a
  /// scrollable.
  ///
  /// This configuration is used when the [title] and [content] are expected
  /// to overflow. Both [title] and [content] are wrapped in a scroll view,
  /// allowing all overflowed content to be visible while still showing the
  /// button bar.
  final bool scrollable;

  /// The spacing between title and content.
  ///
  /// If null, then it will default to 8.0 logical pixels.
  /// If 0.0, then no spacing will be added in between title and content.
  final double? titleContentSpacing;

  /// The spacing between content and actions.
  ///
  /// If null, then it will default to 18.0 logical pixels.
  /// If 0.0, then no spacing will be added in between content and actions.
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
      backgroundColor: backgroundColor,
      elevation: elevation,
      shadowColor: shadowColor,
      surfaceTintColor: surfaceTintColor,
      insetPadding: insetPadding,
      clipBehavior: clipBehavior,
      shape: shape,
      alignment: alignment,
      child: dialogChild,
    );
  }
}

double _scalePadding(double textScaleFactor) {
  final double clampedTextScaleFactor = clampDouble(textScaleFactor, 1.0, 2.0);
  // The final padding scale factor is clamped between 1/3 and 1. For example,
  // a non-scaled padding of 24 will produce a padding between 24 and 8.
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
  TextStyle? get titleTextStyle => _textTheme.headlineSmall;

  @override
  TextStyle? get contentTextStyle => _textTheme.bodyMedium;

  @override
  EdgeInsetsGeometry? get actionsPadding =>
      const EdgeInsets.only(left: 0.0, right: 0.0, bottom: 0.0);
}
