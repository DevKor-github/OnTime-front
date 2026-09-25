import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/shared/constants/app_colors.dart';

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
    final decreaseEnabled = value > lowerBound;
    final buttonStyle = ButtonStyle(
      fixedSize: const WidgetStatePropertyAll(Size(46, 46)),
      padding: const WidgetStatePropertyAll(EdgeInsets.zero),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? AppColors.grey.shade200
            : const Color(0xffdce3ff),
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? AppColors.grey.shade400
            : const Color(0xff3d54bc),
      ),
      side: WidgetStateProperty.resolveWith(
        (states) => BorderSide(
          color: states.contains(WidgetState.disabled)
              ? AppColors.grey.shade300
              : const Color(0xff3d54bc),
        ),
      ),
      shape: const WidgetStatePropertyAll(CircleBorder()),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.remove, size: 24),
          style: buttonStyle,
          onPressed: decreaseEnabled ? onSpareTimeDecreased : null,
        ),
        const SizedBox(width: 34.5),
        Text(
          '${value.inMinutes}분',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: 24.2,
            fontWeight: FontWeight.w400,
            height: 1.8,
          ),
        ),
        const SizedBox(width: 34.5),
        IconButton(
          icon: const Icon(Icons.add, size: 24),
          style: buttonStyle,
          onPressed: onSpareTimeIncreased,
        ),
      ],
    );
  }
}
