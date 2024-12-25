import 'package:flutter/material.dart';

class TimeStepper extends StatelessWidget {
  const TimeStepper({
    super.key,
    required this.onChanged,
    required this.value,
    this.step = 1,
    this.min = 0,
    this.max,
    required this.child,
  });

  final ValueChanged<int> onChanged;
  final int value;
  final int step;
  final int min;
  final int? max;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final iconButtonStyle = ButtonStyle(
      backgroundColor: WidgetStatePropertyAll(Color(0xffe6e9f9)),
      foregroundColor: WidgetStatePropertyAll(colorScheme.primary),
      shape: WidgetStatePropertyAll(CircleBorder(
          side: BorderSide(color: colorScheme.primary, width: 1.0))),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconButton(
            icon: const Icon(Icons.remove),
            style: iconButtonStyle,
            onPressed:
                value - step >= min ? () => onChanged(value - step) : null),
        child,
        IconButton(
          icon: const Icon(Icons.add),
          style: iconButtonStyle,
          onPressed: max != null && value + step > max!
              ? null
              : () => onChanged(value + step),
        ),
      ],
    );
  }
}
