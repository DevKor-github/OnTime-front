import 'package:flutter/widgets.dart';
import 'package:on_time_front/presentation/shared/components/time_stepper.dart';

class ScheduleSpareTimeField extends StatelessWidget {
  const ScheduleSpareTimeField({
    super.key,
    required this.lowerBound,
    required this.spareTime,
    required this.onSpareTimeDecreased,
    required this.onSpareTimeIncreased,
  });

  final Duration spareTime;
  final Duration lowerBound;
  final VoidCallback onSpareTimeIncreased;
  final VoidCallback onSpareTimeDecreased;

  @override
  Widget build(BuildContext context) {
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
          Expanded(child: SizedBox()),
        ],
      ),
    );
  }
}
