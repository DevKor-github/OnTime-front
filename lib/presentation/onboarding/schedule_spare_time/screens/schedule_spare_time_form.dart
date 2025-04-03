import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/core/mixins/overlay_state_mixin.dart';
import 'package:on_time_front/presentation/onboarding/components/onboarding_page_view_layout.dart';
import 'package:on_time_front/presentation/onboarding/schedule_spare_time/components/shcedule_spare_time_field.dart';
import 'package:on_time_front/presentation/onboarding/schedule_spare_time/cubit/schedule_spare_time_cubit.dart';
import 'package:on_time_front/presentation/shared/components/error_message_bubble.dart';

class ScheduleSpareTimeForm extends StatefulWidget {
  const ScheduleSpareTimeForm({
    super.key,
  });

  @override
  State<ScheduleSpareTimeForm> createState() => _ScheduleSpareTimeFormState();
}

class _ScheduleSpareTimeFormState extends State<ScheduleSpareTimeForm>
    with OverlayStateMixin {
  late Duration spareTime;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    removeOverlay();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    removeOverlay();
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return OnboardingPageViewLayout(
      title: '여유시간을 설정해주세요',
      subTitle: RichText(
        text: TextSpan(
          text: '설정한 여유시간만큼 일찍 도착할 수 있어요.\n',
          style: textTheme.titleSmall?.copyWith(
            color: colorScheme.outline,
          ),
          children: [
            TextSpan(
              text: '여유시간은 혹시 모를 상황을 위해 꼭 설정해야 돼요.',
              style: textTheme.titleSmall?.copyWith(
                color: colorScheme.outline,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      child: BlocBuilder<ScheduleSpareTimeCubit, ScheduleSpareTimeState>(
        builder: (context, state) {
          final spareTimeLowerBound =
              context.read<ScheduleSpareTimeCubit>().lowerBound;

          // Defer overlay logic to after the build phase
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (state.spareTime <= spareTimeLowerBound) {
              if (!isOverlayShown) {
                showOverlay(
                  Positioned(
                    top: 420,
                    left: 50,
                    child: ErrorMessageBubble(
                      errorMessage: Text(
                          '여유시간은 ${spareTimeLowerBound.inMinutes}분 아래로 설정할 수 없어요 '),
                      tailPosition: TailPosition.top,
                    ),
                  ),
                );
              }
            } else {
              if (isOverlayShown) {
                removeOverlay();
              }
            }
          });

          return ScheduleSpareTimeField(
            lowerBound: spareTimeLowerBound,
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
