import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/use-cases/get_preparation_by_schedule_id_use_case.dart';

import 'package:on_time_front/presentation/alarm/bloc/alarm_screen_preparation_info/alarm_screen_preparation_info_bloc.dart';
import 'package:on_time_front/presentation/alarm/bloc/alarm_timer/alarm_timer_bloc.dart';
import 'package:on_time_front/presentation/alarm/components/alarm_screen_bottom_section.dart';
import 'package:on_time_front/presentation/alarm/components/alarm_screen_top_section.dart';

class AlarmScreen extends StatelessWidget {
  final ScheduleEntity schedule;

  const AlarmScreen({
    super.key,
    required this.schedule,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AlarmScreenPreparationInfoBloc>(
      create: (context) => AlarmScreenPreparationInfoBloc(
        getPreparationByScheduleIdUseCase:
            context.read<GetPreparationByScheduleIdUseCase>(),
      )..add(
          AlarmScreenPreparationSubscriptionRequested(
            scheduleId: schedule.id,
            schedule: schedule,
          ),
        ),
      child: BlocBuilder<AlarmScreenPreparationInfoBloc,
          AlarmScreenPreparationInfoState>(
        builder: (context, infoState) {
          if (infoState is AlarmScreenPreparationInfoLoadInProgress ||
              infoState is AlarmScreenPreparationInitial) {
            return const Scaffold(
              backgroundColor: Color(0xff5C79FB),
              body: Center(child: CircularProgressIndicator()),
            );
          } else if (infoState is AlarmScreenPreparationLoadFailure) {
            return Scaffold(
              backgroundColor: const Color(0xff5C79FB),
              body: Center(child: Text(infoState.errorMessage)),
            );
          } else if (infoState is AlarmScreenPreparationLoadSuccess) {
            return BlocProvider<AlarmTimerBloc>(
              create: (context) => AlarmTimerBloc(
                preparationSteps: infoState.preparationSteps,
              )..add(
                  AlarmTimerStepStarted(
                    infoState.preparationSteps.first.preparationTime.inSeconds,
                  ),
                ),
              child: _buildAlarmScreen(infoState, context),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildAlarmScreen(
    AlarmScreenPreparationLoadSuccess infoState,
    BuildContext context,
  ) {
    return BlocListener<AlarmTimerBloc, AlarmTimerState>(
      listener: (context, timerState) {
        if (timerState is AlarmTimerPreparationCompletion) {
          GoRouter.of(context).go('/earlyLate', extra: schedule);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xff5C79FB),
        body: Column(
          children: [
            AlarmScreenTopSection(
              isLate: infoState.isLate,
              beforeOutTime: infoState.beforeOutTime,
            ),
            const SizedBox(height: 110),
            const Expanded(child: AlarmScreenBottomSection()),
          ],
        ),
      ),
    );
  }
}
