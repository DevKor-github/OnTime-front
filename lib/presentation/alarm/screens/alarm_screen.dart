import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';

import 'package:on_time_front/presentation/app/bloc/schedule/schedule_bloc.dart';
import 'package:on_time_front/presentation/alarm/components/alarm_screen_bottom_section.dart';
import 'package:on_time_front/presentation/alarm/components/alarm_screen_top_section.dart';
import 'package:on_time_front/presentation/alarm/components/preparation_completion_dialog.dart';

class AlarmScreen extends StatefulWidget {
  const AlarmScreen({super.key});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  bool _hasShownCompletionDialog = false;
  void _onPreparationFinished(
      BuildContext context, Duration timeRemainingBeforeLeaving, bool isLate) {
    final latenessMinutes =
        isLate ? (timeRemainingBeforeLeaving.inMinutes.abs()) : 0;
    context.read<ScheduleBloc>().add(ScheduleFinished(latenessMinutes));
    context.go(
      '/earlyLate',
      extra: {
        'earlyLateTime': timeRemainingBeforeLeaving.inSeconds,
        'isLate': isLate,
      },
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ScheduleBloc>().add(const ScheduleSubscriptionRequested());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ScheduleBloc, ScheduleState>(
      builder: (context, scheduleState) {
        if (scheduleState.status == ScheduleStatus.ongoing ||
            scheduleState.status == ScheduleStatus.started) {
          final schedule = scheduleState.schedule!;
          final preparation = schedule.preparation;

          if (preparation.isAllStepsDone && !_hasShownCompletionDialog) {
            _hasShownCompletionDialog = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              showPreparationCompletionDialog(
                context: context,
                onFinish: () {
                  _onPreparationFinished(
                    context,
                    schedule.timeRemainingBeforeLeaving,
                    schedule.isLate,
                  );
                },
              );
            });
          }

          return _buildAlarmScreen(
            schedule: schedule,
          );
        } else {
          return const Scaffold(
            backgroundColor: Color(0xff5C79FB),
            body: Center(child: CircularProgressIndicator()),
          );
        }
      },
    );
  }

  Widget _buildAlarmScreen({
    required ScheduleWithPreparationEntity schedule,
  }) {
    final preparation = schedule.preparation;
    return Scaffold(
      backgroundColor: const Color(0xff5C79FB),
      body: Stack(
        children: [
          Column(
            children: [
              AlarmScreenTopSection(
                isLate: schedule.isLate,
                beforeOutTime: schedule.timeRemainingBeforeLeaving.inSeconds,
                preparationName: preparation.currentStepName,
                preparationRemainingTime:
                    preparation.currentStepRemainingTime.inSeconds,
                progress: preparation.progress,
              ),
              const SizedBox(height: 110),
              Expanded(
                child: AlarmScreenBottomSection(
                  preparation: preparation,
                  onSkip: () {
                    context
                        .read<ScheduleBloc>()
                        .add(const ScheduleStepSkipped());
                  },
                  onEndPreparation: () => _onPreparationFinished(context,
                      schedule.timeRemainingBeforeLeaving, schedule.isLate),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
