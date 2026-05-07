import 'package:flutter/widgets.dart';
import 'package:on_time_front/presentation/shared/components/error_message_bubble.dart';
import 'package:on_time_front/presentation/shared/components/time_stepper.dart';

class ScheduleSpareTimeField extends StatelessWidget {
  const ScheduleSpareTimeField({
    super.key,
    required this.lowerBound,
    required this.spareTime,
    required this.minimumWarningMessage,
    required this.onSpareTimeDecreased,
    required this.onSpareTimeIncreased,
  });

  final Duration spareTime;
  final Duration lowerBound;
  final String minimumWarningMessage;
  final VoidCallback onSpareTimeIncreased;
  final VoidCallback onSpareTimeDecreased;

  @override
  Widget build(BuildContext context) {
    final isAtMinimum = spareTime <= lowerBound;

    return Padding(
      padding: EdgeInsets.only(top: 90.0),
      child: Column(
        children: [
          TimeStepper(
            onSpareTimeIncreased: onSpareTimeIncreased,
            onSpareTimeDecreased: onSpareTimeDecreased,
            lowerBound: lowerBound,
            value: spareTime,
          ),
          if (isAtMinimum)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ErrorMessageBubble(
                width: 300,
                padding: const EdgeInsets.only(left: 72),
                tailPosition: TailPosition.top,
                errorMessage: Text(minimumWarningMessage),
              ),
            ),
          Expanded(child: SizedBox()),
        ],
      ),
    );
  }
}
