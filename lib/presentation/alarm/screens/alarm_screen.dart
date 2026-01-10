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
  bool _navigateAfterFinish = false;
  int? _pendingEarlyLateSeconds;
  bool? _pendingIsLate;

  void _resetFinishNavigation() {
    _navigateAfterFinish = false;
    _pendingEarlyLateSeconds = null;
    _pendingIsLate = null;
  }

  void _onPreparationFinished(
      BuildContext context, Duration timeRemainingBeforeLeaving, bool isLate) {
    final latenessMinutes =
        isLate ? (timeRemainingBeforeLeaving.inMinutes.abs()) : 0;
    _pendingEarlyLateSeconds = timeRemainingBeforeLeaving.inSeconds;
    _pendingIsLate = isLate;
    _navigateAfterFinish = true;
    context.read<ScheduleBloc>().add(ScheduleFinished(latenessMinutes));
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
    return BlocListener<ScheduleBloc, ScheduleState>(
      listenWhen: (previous, current) {
        return _navigateAfterFinish &&
            previous.status != ScheduleStatus.notExists &&
            current.status == ScheduleStatus.notExists;
      },
      listener: (context, scheduleState) {
        final earlyLateSeconds = _pendingEarlyLateSeconds;
        final isLate = _pendingIsLate;
        _resetFinishNavigation();
        if (earlyLateSeconds != null && isLate != null) {
          context.go(
            '/earlyLate',
            extra: {
              'earlyLateTime': earlyLateSeconds,
              'isLate': isLate,
            },
          );
        }
      },
      child: BlocBuilder<ScheduleBloc, ScheduleState>(
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
      ),
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
