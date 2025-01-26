import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class WeekCalendar extends StatelessWidget with Diagnosticable {
  const WeekCalendar(
      {super.key,
      required this.date,
      required this.onDateSelected,
      required this.highlightedDates});

  final DateTime date;
  final ValueChanged<DateTime> onDateSelected;
  final List<DateTime> highlightedDates;

  DateTime get firstDayOfWeek {
    final DateTime firstDay = DateTime.utc(date.year, date.month, date.day);
    return firstDay.subtract(Duration(days: firstDay.weekday - 1));
  }

  DateTile _buildDateTile(DateTime date) {
    if (date.month == DateTime.now().month &&
        date.day == DateTime.now().day &&
        date.year == DateTime.now().year) {
      return DateTile.filled(
        date: date,
        onTap: () => onDateSelected(date),
      );
    }
    if (highlightedDates.firstWhereOrNull((highlightedDate) =>
            highlightedDate.month == date.month &&
            highlightedDate.day == date.day &&
            highlightedDate.year == date.year) !=
        null) {
      return DateTile.outlined(
        date: date,
        onTap: () => onDateSelected(date),
      );
    }
    return DateTile(
      date: date,
      onTap: () => onDateSelected(date),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (int i = 0; i < 7; i++)
            _buildDateTile(firstDayOfWeek.add(Duration(days: i))),
        ],
      ),
    );
  }
}

class DateTileThemeData extends ThemeExtension<DateTileThemeData> {
  const DateTileThemeData({
    this.style,
  });

  final DateTileStyle? style;

  @override
  int get hashCode {
    return style.hashCode;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DateTileThemeData && other.style == style;
  }

  @override
  ThemeExtension<DateTileThemeData> copyWith() {
    return DateTileThemeData(
      style: style,
    );
  }

  @override
  ThemeExtension<DateTileThemeData> lerp(
      covariant ThemeExtension<DateTileThemeData>? other, double t) {
    if (other == null) return this;
    final otherData = other as DateTileThemeData;
    return DateTileThemeData(
      style: DateTileStyle.lerp(style, otherData.style, t),
    );
  }
}

class DateTileStyle {
  const DateTileStyle({
    this.textStyle,
    this.backgroundColor,
    this.forgroundColor,
    this.shape,
    this.side,
  });

  /// The style for a dateTile's [Text] widget descendants.
  ///
  /// The color of the [textStyle] is typically not used directly, the
  /// [foregroundColor] is used instead.
  final WidgetStateProperty<TextStyle?>? textStyle;

  /// The dateTile's background fill color.
  final WidgetStateProperty<Color?>? backgroundColor;

  /// The color for the tile's [Text] descendants.
  ///
  /// This color is typically used instead of the color of the [textStyle]. All
  /// of the components that compute defaults from [DateTileStyle] values
  /// compute a default [foregroundColor] and use that instead of the
  /// [textStyle]'s color.
  final WidgetStateProperty<Color?>? forgroundColor;

  /// The color and weight of the dateTile's outline.
  ///
  /// This value is combined with [shape] to create a shape decorated
  /// with an outline.
  final WidgetStateProperty<OutlinedBorder?>? shape;

  /// The color and weight of the dateTile's outline.
  final WidgetStateProperty<BorderSide?>? side;

  /// Returns a copy of this [DateTileStyle] with the given fields replaced
  /// by the new values.
  DateTileStyle copyWith({
    WidgetStateProperty<TextStyle?>? textStyle,
    WidgetStateProperty<Color?>? backgroundColor,
    WidgetStateProperty<Color?>? forgroundColor,
    WidgetStateProperty<OutlinedBorder?>? shape,
    WidgetStateProperty<BorderSide?>? side,
  }) {
    return DateTileStyle(
      textStyle: textStyle ?? this.textStyle,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      forgroundColor: forgroundColor ?? this.forgroundColor,
      shape: shape ?? this.shape,
      side: side ?? this.side,
    );
  }

  DateTileStyle merge(DateTileStyle? style) {
    if (style == null) return this;
    return copyWith(
      textStyle: textStyle ?? style.textStyle,
      backgroundColor: backgroundColor ?? style.backgroundColor,
      forgroundColor: forgroundColor ?? style.forgroundColor,
      shape: shape ?? style.shape,
      side: side ?? style.side,
    );
  }

  @override
  int get hashCode {
    final List<Object?> values = <Object?>[
      textStyle,
      backgroundColor,
      forgroundColor,
      shape,
      side,
    ];
    return Object.hashAll(values);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    return other is DateTileStyle &&
        other.textStyle == textStyle &&
        other.backgroundColor == backgroundColor &&
        other.forgroundColor == forgroundColor &&
        other.shape == shape &&
        other.side == side;
  }

  static DateTileStyle? lerp(DateTileStyle? a, DateTileStyle? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    return DateTileStyle(
      textStyle: WidgetStateProperty.lerp<TextStyle?>(
          a?.textStyle, b?.textStyle, t, TextStyle.lerp),
      backgroundColor: WidgetStateProperty.lerp<Color?>(
          a?.backgroundColor, b?.backgroundColor, t, Color.lerp),
      forgroundColor: WidgetStateProperty.lerp<Color?>(
          a?.forgroundColor, b?.forgroundColor, t, Color.lerp),
      shape: WidgetStateProperty.lerp<OutlinedBorder?>(
          a?.shape, b?.shape, t, OutlinedBorder.lerp),
      side: _lerpSides(a?.side, b?.side, t),
    );
  }

  static WidgetStateProperty<BorderSide?>? _lerpSides(
      WidgetStateProperty<BorderSide?>? a,
      WidgetStateProperty<BorderSide?>? b,
      double t) {
    if (a == null && b == null) {
      return null;
    }
    return WidgetStateBorderSide.lerp(a, b, t);
  }
}

enum _DateTileVariant {
  outlined,
  filled,
  defualt,
}

class DateTile extends StatefulWidget {
  const DateTile({super.key, this.style, required this.date, this.onTap})
      : _variant = _DateTileVariant.defualt;

  final DateTileStyle? style;
  final DateTime date;
  final VoidCallback? onTap;

  final _DateTileVariant _variant;

  bool get enabled => onTap != null;

  const DateTile.filled({
    super.key,
    this.style,
    required this.date,
    this.onTap,
  }) : _variant = _DateTileVariant.filled;

  const DateTile.outlined({
    super.key,
    this.style,
    required this.date,
    this.onTap,
  }) : _variant = _DateTileVariant.outlined;

  @override
  State<DateTile> createState() => _DateTileState();
}

class _DateTileState extends State<DateTile> with TickerProviderStateMixin {
  late WidgetStatesController statesController;

  void handleStatesControllerChange() {
    // Schedule a rebuild to resolve MaterialStateProperty properties
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void initStatesController() {
    statesController = WidgetStatesController();
    statesController.update(WidgetState.disabled, !widget.enabled);
    statesController.addListener(handleStatesControllerChange);
  }

  @override
  void initState() {
    super.initState();
    initStatesController();
  }

  @override
  void didUpdateWidget(DateTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      statesController.update(WidgetState.disabled, !widget.enabled);
      if (!widget.enabled) {
        // The button may have been disabled while a press gesture is currently underway.
        statesController.update(WidgetState.pressed, false);
      }
    }
  }

  DateTileStyle defualtStyleOf(BuildContext context) {
    return switch (widget._variant) {
      _DateTileVariant.defualt => _DefaultDateTileStyle(context),
      _DateTileVariant.filled => _FilledDateTileStyle(context),
      _DateTileVariant.outlined => _OutlinedDateTileStyle(context),
    };
  }

  DateTileStyle? themeStyleOf(BuildContext context) {
    return Theme.of(context).extension<DateTileThemeData>()?.style;
  }

  @override
  Widget build(BuildContext context) {
    final DateTileStyle? widgetStyle = widget.style;
    final DateTileStyle? themeStyle = themeStyleOf(context);
    final DateTileStyle defaultStyle = defualtStyleOf(context);

    T? effectiveValue<T>(T? Function(DateTileStyle? style) getProperty) {
      final T? widgetValue = getProperty(widgetStyle);
      final T? themeValue = getProperty(themeStyle);
      final T? defaultValue = getProperty(defaultStyle);
      return widgetValue ?? themeValue ?? defaultValue;
    }

    T? resolve<T>(
        WidgetStateProperty<T?>? Function(DateTileStyle? style) getProperty) {
      return effectiveValue((DateTileStyle? style) {
        return getProperty(style)?.resolve(statesController.value);
      });
    }

    final TextStyle? resolvedTextStyle =
        resolve<TextStyle?>((DateTileStyle? style) => style?.textStyle);
    final Color? resolvedBackgroundColor =
        resolve<Color?>((DateTileStyle? style) => style?.backgroundColor);
    final Color? resolvedForgroundColor =
        resolve<Color?>((DateTileStyle? style) => style?.forgroundColor);
    final OutlinedBorder? resolvedShape =
        resolve<OutlinedBorder?>((DateTileStyle? style) => style?.shape);
    final BorderSide? resolvedSide =
        resolve<BorderSide?>((DateTileStyle? style) => style?.side);

    return GestureDetector(
      onTap: widget.onTap,
      child: Material(
        textStyle: resolvedTextStyle!.copyWith(color: resolvedForgroundColor),
        shape: resolvedShape!.copyWith(side: resolvedSide),
        color: resolvedBackgroundColor,
        type: resolvedBackgroundColor == null
            ? MaterialType.transparency
            : MaterialType.button,
        child: InkWell(
          statesController: statesController,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 8.0, horizontal: 11.0),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_nameOfDay(widget.date.weekday)),
                  Text(widget.date.day.toString()),
                ]),
          ),
        ),
      ),
    );
  }

  String _nameOfDay(int day) {
    switch (day) {
      case 1:
        return '월';
      case 2:
        return '화';
      case 3:
        return '수';
      case 4:
        return '목';
      case 5:
        return '금';
      case 6:
        return '토';
      case 7:
        return '일';
      default:
        return '';
    }
  }
}

class _DefaultDateTileStyle extends DateTileStyle {
  _DefaultDateTileStyle(this.context) : super();

  final BuildContext context;
  late final ColorScheme _colorScheme = Theme.of(context).colorScheme;

  @override
  WidgetStateProperty<TextStyle?> get textStyle {
    return WidgetStateProperty.all(Theme.of(context).textTheme.bodyMedium);
  }

  @override
  WidgetStateProperty<Color?> get forgroundColor {
    return WidgetStateProperty.all(_colorScheme.onSurface);
  }

  @override
  WidgetStateProperty<BorderSide?> get side {
    return WidgetStateProperty.all(BorderSide.none);
  }
}

class _FilledDateTileStyle extends DateTileStyle {
  _FilledDateTileStyle(this.context) : super();

  final BuildContext context;
  late final ColorScheme _colorScheme = Theme.of(context).colorScheme;

  @override
  WidgetStateProperty<Color?> get backgroundColor {
    return WidgetStateProperty.all(_colorScheme.primary);
  }

  @override
  WidgetStateProperty<Color?> get forgroundColor {
    return WidgetStateProperty.all(_colorScheme.onPrimary);
  }

  @override
  WidgetStateProperty<BorderSide?> get side {
    return WidgetStateProperty.all(BorderSide.none);
  }
}

class _OutlinedDateTileStyle extends DateTileStyle {
  _OutlinedDateTileStyle(this.context) : super();

  final BuildContext context;
  late final ColorScheme _colorScheme = Theme.of(context).colorScheme;

  @override
  WidgetStateProperty<Color?> get forgroundColor {
    return WidgetStateProperty.all(_colorScheme.onSurface);
  }

  @override
  WidgetStateProperty<BorderSide?> get side {
    return WidgetStateProperty.all(
        BorderSide(color: _colorScheme.primary, width: 1.0));
  }
}
