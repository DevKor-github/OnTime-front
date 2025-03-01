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
    final colorScheme = Theme.of(context).colorScheme;
    return OnboardingPageViewLayout(
      title: '여유시간을 설정해주세요',
      subTitle: RichText(
        text: TextSpan(
          text: '설정한 여유시간만큼 일찍 도착할 수 있어요.\n',
          style: TextStyle(
            color: colorScheme.outline,
            fontSize: 16,
          ),
          children: [
            TextSpan(
                text: '여유시간은 혹시 모를 상황을 위해 꼭 설정해야 돼요.',
                style: TextStyle(
                    color: colorScheme.outline,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
          ],
        ),
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
