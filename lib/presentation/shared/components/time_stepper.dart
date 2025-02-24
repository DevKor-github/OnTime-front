import 'package:flutter/material.dart';

class TimeStepper extends StatelessWidget {
  const TimeStepper({
    super.key,
    required this.onSpareTimeIncreased,
    required this.onSpareTimeDecreased,
    required this.lowerBound,
    required this.value,
  });

  final VoidCallback onSpareTimeIncreased;
  final VoidCallback onSpareTimeDecreased;
  final Duration lowerBound;
  final Duration value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
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
            onPressed: value > lowerBound ? onSpareTimeDecreased : null),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 35.0),
          child: Text(
            '${value.inMinutes}분',
            style: textTheme.titleSmall,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          style: iconButtonStyle,
          onPressed: onSpareTimeIncreased,
        ),
      ],
    );
  }
}
