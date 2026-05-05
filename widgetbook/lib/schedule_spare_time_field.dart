import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/onboarding/schedule_spare_time/components/shcedule_spare_time_field.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: 'default',
  type: ScheduleSpareTimeField,
)
Widget useCaseScheduleSpareTimeField(BuildContext context) {
  final initialMinutes = context.knobs.int.input(
    label: 'Initial Minutes',
    initialValue: 10,
  );

  return _ScheduleSpareTimeFieldUseCase(initialMinutes: initialMinutes);
}

class _ScheduleSpareTimeFieldUseCase extends StatefulWidget {
  const _ScheduleSpareTimeFieldUseCase({required this.initialMinutes});

  final int initialMinutes;

  @override
  State<_ScheduleSpareTimeFieldUseCase> createState() =>
      _ScheduleSpareTimeFieldUseCaseState();
}

class _ScheduleSpareTimeFieldUseCaseState
    extends State<_ScheduleSpareTimeFieldUseCase> {
  static const _lowerBound = Duration(minutes: 10);
  late Duration _spareTime;

  @override
  void initState() {
    super.initState();
    _spareTime = _normalizedInitialSpareTime;
  }

  @override
  void didUpdateWidget(covariant _ScheduleSpareTimeFieldUseCase oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialMinutes != widget.initialMinutes) {
      _spareTime = _normalizedInitialSpareTime;
    }
  }

  Duration get _normalizedInitialSpareTime {
    final initialSpareTime = Duration(minutes: widget.initialMinutes);
    return initialSpareTime < _lowerBound ? _lowerBound : initialSpareTime;
  }

  @override
  Widget build(BuildContext context) {
    return ScheduleSpareTimeField(
      lowerBound: _lowerBound,
      spareTime: _spareTime,
      minimumWarningMessage: '여유시간은 10분 아래로 설정할 수 없어요',
      onSpareTimeDecreased: () {
        setState(() {
          final updatedSpareTime = _spareTime - const Duration(minutes: 10);
          if (updatedSpareTime >= _lowerBound) {
            _spareTime = updatedSpareTime;
          }
        });
      },
      onSpareTimeIncreased: () {
        setState(() {
          _spareTime += const Duration(minutes: 10);
        });
      },
    );
  }
}
