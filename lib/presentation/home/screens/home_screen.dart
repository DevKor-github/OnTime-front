import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/presentation/app/bloc/app_bloc.dart';
import 'package:on_time_front/presentation/home/bloc/weekly_schedules_bloc.dart';
import 'package:on_time_front/presentation/home/components/home_app_bar.dart';
import 'package:on_time_front/presentation/home/components/todays_schedule_tile.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/presentation/home/components/week_calendar.dart';
import 'package:on_time_front/presentation/shared/components/arc_indicator.dart';
import 'package:on_time_front/presentation/shared/constants/app_colors.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation _animation;
  OverlayEntry? _overlayEntry;
  final GlobalKey _overlayKey = GlobalKey();

  final arrowRightSvg = SvgPicture.asset(
    'assets/arrow_right.svg',
    semanticsLabel: 'arrow right',
    height: 24,
    fit: BoxFit.contain,
  );

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateOfToday = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day, 0, 0, 0);
    final theme = Theme.of(context);
    final double score = context.select((AppBloc bloc) =>
        bloc.state.user.mapOrNull((user) => user.score) ?? -1);
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..forward();
    _animation = _animationController.drive(
      Tween<double>(begin: 0, end: score / 100),
    );
    return BlocProvider(
      create: (context) => getIt.get<WeeklySchedulesBloc>()
        ..add(WeeklySchedulesSubscriptionRequested(date: dateOfToday)),
      child: Scaffold(
        appBar: HomeAppBar(),
        body: Column(
          children: [
            Stack(alignment: Alignment.bottomCenter, children: [
              Padding(
                key: _overlayKey,
                padding: const EdgeInsets.only(bottom: 40.0),
                child: AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return SizedBox(
                        width: 325,
                        child: CustomPaint(
                          painter: ArcIndicator(
                            strokeWidth: 16,
                            progress: _animation.value,
                          ),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                  top: 52.0, right: 60.0, left: 60.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('${score.toInt()}점',
                                      style: theme.textTheme.displaySmall),
                                  SizedBox(height: 6.0),
                                  Text(
                                    '성실도 점수 30점 올랐어요!\n약속을 잘 지키고 있네요',
                                    style: theme.textTheme.bodySmall,
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: 6.0),
                                  SizedBox(
                                      height: 270.3,
                                      child:
                                          Image.asset('assets/character.png')),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
              ),
              BlocBuilder<WeeklySchedulesBloc, WeeklySchedulesState>(
                  builder: (context, state) {
                if (state.status == WeeklySchedulesStatus.success) {
                  return todaysScheduleOverlayBuilder(state.todaySchedule);
                } else {
                  return CircularProgressIndicator();
                }
              }),
            ]),
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.blue[100],
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.only(top: 0.0, left: 16.0, right: 16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('이번 주 약속', style: theme.textTheme.titleSmall),
                          TextButton(
                            onPressed: () {
                              context.go('/calendar');
                            },
                            child: Row(
                              children: [
                                Text('캘린더 보기',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                        color:
                                            theme.colorScheme.outlineVariant)),
                                arrowRightSvg,
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 23.0),
                      BlocBuilder<WeeklySchedulesBloc, WeeklySchedulesState>(
                          builder: (context, state) {
                        if (state.schedules.isEmpty) {
                          if (state.status == WeeklySchedulesStatus.loading) {
                            return CircularProgressIndicator();
                          } else if (state.status !=
                              WeeklySchedulesStatus.success) {
                            return const SizedBox();
                          }
                        }

                        return WeekCalendar(
                          date: DateTime.now(),
                          onDateSelected: (date) {},
                          highlightedDates: state.dates,
                        );
                      }),
                      Expanded(
                        child: SizedBox(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            context.go('/scheduleCreate');
          },
          child: Icon(Icons.add),
        ),
        //bottomNavigationBar: CustomBottomNavigationBar(),
      ),
    );
  }

  Widget todaysScheduleOverlayBuilder(ScheduleEntity? todaySchedule) {
    final theme = Theme.of(context);
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          height: 21 + 16,
          decoration: BoxDecoration(color: AppColors.blue[100]),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Material(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            color: theme.colorScheme.surface,
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '오늘의 약속',
                    style: theme.textTheme.titleMedium,
                  ),
                  SizedBox(height: 21.0),
                  TodaysScheduleTile(
                    schedule: todaySchedule,
                  )
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
