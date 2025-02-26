import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/presentation/onboarding/components/onboarding_page_view_layout.dart';
import 'package:on_time_front/presentation/onboarding/schedule_spare_time/components/shcedule_spare_time_field.dart';
import 'package:on_time_front/presentation/onboarding/schedule_spare_time/cubit/schedule_spare_time_cubit.dart';

class ScheduleSpareTimeForm extends StatefulWidget {
  const ScheduleSpareTimeForm({
    super.key,
  });

  @override
  State<ScheduleSpareTimeForm> createState() => _ScheduleSpareTimeFormState();
}

class _ScheduleSpareTimeFormState extends State<ScheduleSpareTimeForm> {
  late Duration spareTime;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return OnboardingPageViewLayout(
      title: Text(
        '여유시간을 설정해주세요',
        style: textTheme.titleLarge,
      ),
      child: BlocBuilder<ScheduleSpareTimeCubit, ScheduleSpareTimeState>(
        builder: (context, state) {
          return ScheduleSpareTimeField(
            lowerBound: context.read<ScheduleSpareTimeCubit>().lowerBound,
            spareTime: state.spareTime,
            onSpareTimeDecreased: () {
              context.read<ScheduleSpareTimeCubit>().spareTimeDecreased();
            },
            onSpareTimeIncreased: () {
              context.read<ScheduleSpareTimeCubit>().spareTimeIncreased();
            },
          );
        },
      ),
    );
  }
}
