import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/core/dio/app_dio.dart';
import 'package:on_time_front/data/data_sources/preparation_remote_data_source.dart';

import 'package:on_time_front/presentation/alarm/bloc/alarm_screen/alarm_screen_preparation_info/alarm_screen_preparation_info_bloc.dart';
import 'package:on_time_front/presentation/alarm/bloc/alarm_screen/alarm_timer/alarm_timer_bloc.dart';
import 'package:on_time_front/presentation/alarm/components/alarm_screen/alarm_graph_component.dart';
import 'package:on_time_front/presentation/alarm/components/alarm_screen/preparation_step_list_widget.dart';

import 'package:on_time_front/presentation/alarm/screeens/early_late_screen.dart';
import 'package:on_time_front/presentation/shared/components/button.dart';
import 'package:on_time_front/presentation/shared/utils/time_format.dart';

class AlarmScreen extends StatefulWidget {
  final ScheduleEntity schedule;
  const AlarmScreen({super.key, required this.schedule});

  @override
  _AlarmScreenState createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;
  double currentProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    )..addListener(() {
        setState(() {
          currentProgress = _progressAnimation.value;
        });
      });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AlarmScreenPreparationInfoBloc>(
      create: (context) => AlarmScreenPreparationInfoBloc(
        preparationRemoteDataSource: PreparationRemoteDataSourceImpl(
          AppDio(),
        ),
      )..add(
          FetchPreparationInfo(
              scheduleId: widget.schedule.id, schedule: widget.schedule),
        ),
      child: BlocBuilder<AlarmScreenPreparationInfoBloc,
          AlarmScreenPreparationInfoState>(
        builder: (context, infoState) {
          if (infoState is PreparationInfoLoadInProgress ||
              infoState is PreparationInfoInitial) {
            return const Scaffold(
                backgroundColor: Color(0xff5C79FB),
                body: Center(child: CircularProgressIndicator()));
          } else if (infoState is PreparationInfoLoadFailure) {
            return Scaffold(
                backgroundColor: const Color(0xff5C79FB),
                body: Center(child: Text(infoState.errorMessage)));
          } else if (infoState is PreparationInfoLoadSuccess) {
            final stepDurations = infoState.preparationSteps
                .map((step) => step.preparationTime.inSeconds)
                .toList();
            return MultiBlocProvider(
              providers: [
                BlocProvider<AlarmTimerBloc>(
                  create: (context) => AlarmTimerBloc(
                      preparationSteps: infoState.preparationSteps)
                    ..add(TimerStepStarted(stepDurations[0])),
                ),
              ],
              child: _buildAlarmScreen(infoState),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildAlarmScreen(PreparationInfoLoadSuccess infoState) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AlarmTimerBloc, AlarmTimerState>(
          listener: (context, timerState) {
            if (timerState is TimerRunInProgress) {
              _progressAnimation = Tween<double>(
                begin: currentProgress,
                end: infoState.progress,
              ).animate(
                CurvedAnimation(
                  parent: _animationController,
                  curve: Curves.easeInOut,
                ),
              );
              _animationController.reset();
              _animationController.forward();
            }
            if (timerState is TimerAllCompleted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => EarlyLateScreen(
                    earlyLateTime: infoState.fullTime,
                  ),
                ),
              );
            }
          },
        ),
      ],
      child: Scaffold(
        backgroundColor: const Color(0xff5C79FB),
        body: Column(
          children: [
            // 상단 텍스트
            Padding(
              padding: const EdgeInsets.only(top: 52),
              child: Text(
                infoState.isLate
                    ? '지각이에요!'
                    : '${formatTime(infoState.fullTime)} 뒤에 나가야 해요',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            // 타이머 그래프 영역
            SizedBox(
              height: 190,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(230, 115),
                    // 타이머 그래프
                    painter: AlarmGraphComponent(
                      progress: currentProgress,
                      preparationRatios: infoState.preparationRatios,
                      preparationCompleted: infoState.preparationCompleted,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 100),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        BlocBuilder<AlarmTimerBloc, AlarmTimerState>(
                          builder: (context, timerState) {
                            String preparationName = "";
                            if (timerState is TimerRunInProgress) {
                              preparationName = infoState
                                  .preparationSteps[timerState.currentStepIndex]
                                  .preparationName;
                            }
                            return Text(
                              preparationName, // 준비 과정 이름
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xffDCE3FF),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        // 각 준비과정의 남은 시간 표시
                        BlocBuilder<AlarmTimerBloc, AlarmTimerState>(
                          builder: (context, timerState) {
                            int remainingTime = 0;
                            if (timerState is TimerRunInProgress) {
                              remainingTime = timerState.remainingTime;
                            }
                            return Text(
                              formatTimeTimer(remainingTime),
                              style: const TextStyle(
                                fontSize: 35,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 110),

            // 하단 영역: 준비 단계 목록과 종료 버튼
            Expanded(
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xffF6F6F6),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(18),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 15,
                    left: MediaQuery.of(context).size.width * 0.06,
                    right: MediaQuery.of(context).size.width * 0.06,
                    bottom: 100,
                    child: Builder(
                      builder: (context) {
                        return PreparationStepListWidget(
                          preparations: infoState.preparationSteps,
                          onSkip: () {
                            context
                                .read<AlarmTimerBloc>()
                                .add(const TimerStepSkipped());
                          },
                        );
                      },
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Builder(
                      builder: (context) {
                        return Stack(
                          children: [
                            SizedBox(
                              width: MediaQuery.of(context).size.width,
                              height: 90,
                              child: Container(
                                color: Colors.white,
                              ),
                            ),
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Button(
                                  text: '준비 종료',
                                  onPressed: () {
                                    context
                                        .read<AlarmTimerBloc>()
                                        .add(const TimerStepFinalized());
                                  },
                                ),
                              ),
                            )
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
