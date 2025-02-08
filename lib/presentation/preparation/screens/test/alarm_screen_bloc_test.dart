import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/core/dio/app_dio.dart';
import 'package:on_time_front/data/data_sources/preparation_remote_data_source.dart';
import 'package:on_time_front/presentation/preparation/bloc/alarm_screen_bloc.dart';
import 'package:on_time_front/presentation/preparation/components/preparation_step_list_widget.dart';
import 'package:on_time_front/presentation/preparation/components/alarm_graph_component.dart';
import 'package:on_time_front/presentation/preparation/screens/early_late_screen.dart';
import 'package:on_time_front/presentation/shared/components/button.dart';
import 'package:on_time_front/utils/time_format.dart';

class AlarmScreenBlocTest extends StatelessWidget {
  final ScheduleEntity schedule;
  const AlarmScreenBlocTest({super.key, required this.schedule});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AlarmScreenBloc(
        scheduleId: schedule.id,
        schedule: schedule,
        preparationRemoteDataSource:
            // PreparationRemoteDataSourceImpl(AppDio())),
            PreparationRemoteDataSourceImpl(Dio()), // AppDio 대신 Dio 사용
      )..add(AlarmScreenFetchPreparation(schedule.id)),
      child: Scaffold(
        backgroundColor: const Color(0xff5C79FB),
        body: BlocListener<AlarmScreenBloc, AlarmScreenState>(
          listener: (context, state) {
            if (state is AlarmScreenMoveToEarlyLateScreen) {
              // context.go('/earlyLate', extra: fullTime);

              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => EarlyLateScreen(
                    earlyLateTime: state.earlyLateTime,
                  ),
                ),
              );
            }
          },
          child: BlocBuilder<AlarmScreenBloc, AlarmScreenState>(
            builder: (context, state) {
              if (state is AlarmScreenLoading || state is AlarmScreenInitial) {
                return const Center(child: CircularProgressIndicator());
              } else if (state is AlarmScreenLoaded) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 52),
                      child: Text(
                        state.isLate
                            ? '지각이에요!'
                            : '${formatTime(state.fullTime)} 뒤에 나가야 해요',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 190,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: const Size(230, 115),
                            painter: AlarmGraphComponent(
                              progress: state.progress,
                              preparationRatios: state.preparationRatios,
                              preparationCompleted: state.preparationCompleted,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 100),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  state.preparationSteps[state.currentIndex]
                                      .preparationName,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xffDCE3FF),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  formatTimeTimer(state.remainingTime),
                                  style: const TextStyle(
                                    fontSize: 35,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 110),
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
                            child: PreparationStepListWidget(
                              preparations: state.preparationSteps,
                              elapsedTimes: state.elapsedTimes,
                              currentIndex: state.currentIndex,
                              onSkip: () => context
                                  .read<AlarmScreenBloc>()
                                  .add(const AlarmScreenSkipPreparation()),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Stack(
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
                                      onPressed: () =>
                                          context.read<AlarmScreenBloc>().add(
                                                const AlarmScreenFinalizePreparation(),
                                              ),
                                    ),
                                  ),
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              } else if (state is AlarmScreenError) {
                return Center(child: Text(state.errorMessage));
              } else {
                return const SizedBox.shrink();
              }
            },
          ),
        ),
      ),
    );
  }
}
