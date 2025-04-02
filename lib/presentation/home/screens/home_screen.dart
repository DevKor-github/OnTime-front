import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/presentation/app/bloc/app_bloc.dart';
import 'package:on_time_front/presentation/home/bloc/weekly_schedules_bloc.dart';
import 'package:on_time_front/presentation/home/components/todays_schedule_tile.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/presentation/home/components/week_calendar.dart';
import 'package:on_time_front/presentation/shared/components/arc_indicator.dart';
import 'package:on_time_front/presentation/shared/constants/app_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final dateOfToday = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day, 0, 0, 0);
    final double score = context.select((AppBloc bloc) =>
        bloc.state.user.mapOrNull((user) => user.score) ?? -1);

    return BlocProvider(
      create: (context) => getIt.get<WeeklySchedulesBloc>()
        ..add(WeeklySchedulesSubscriptionRequested(date: dateOfToday)),
      child: BlocBuilder<WeeklySchedulesBloc, WeeklySchedulesState>(
        builder: (context, state) {
          return Container(
            color: AppColors.white,
            child: Column(
              children: [
                SizedBox(height: 58.0),
                Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    _PunctualityIndicator(score: score),
                    todaysScheduleOverlayBuilder(state),
                  ],
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.only(
                        top: 50.0, left: 16.0, right: 16.0),
                    decoration: BoxDecoration(
                      color: AppColors.blue[100],
                    ),
                    child: _WeeklySchedule(
                      weeklySchedulesState: state,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget todaysScheduleOverlayBuilder(WeeklySchedulesState state) {
    final theme = Theme.of(context);

    if (state.status == WeeklySchedulesStatus.success) {
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
                      schedule: state.todaySchedule,
                    )
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      return CircularProgressIndicator();
    }
  }
}

class _WeeklySchedule extends StatelessWidget {
  const _WeeklySchedule({
    required this.weeklySchedulesState,
  });

  final WeeklySchedulesState weeklySchedulesState;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _WeeklyScheduleHeader(),
        SizedBox(height: 23.0),
        _WeekCalendar(
          weeklySchedulesState: weeklySchedulesState,
        ),
        Expanded(
          child: SizedBox(),
        ),
      ],
    );
  }
}

class _WeeklyScheduleHeader extends StatelessWidget {
  _WeeklyScheduleHeader();

  final arrowRightSvg = SvgPicture.asset(
    'arrow_right.svg',
    package: 'assets',
    semanticsLabel: 'arrow right',
    height: 24,
    fit: BoxFit.contain,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
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
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outlineVariant)),
              arrowRightSvg,
            ],
          ),
        ),
      ],
    );
  }
}

class _WeekCalendar extends StatelessWidget {
  const _WeekCalendar({required this.weeklySchedulesState});

  final WeeklySchedulesState weeklySchedulesState;

  @override
  Widget build(BuildContext context) {
    if (weeklySchedulesState.schedules.isEmpty) {
      if (weeklySchedulesState.status == WeeklySchedulesStatus.loading) {
        return CircularProgressIndicator();
      } else if (weeklySchedulesState.status != WeeklySchedulesStatus.success) {
        return const SizedBox();
      }
    }

    return WeekCalendar(
      date: DateTime.now(),
      onDateSelected: (date) {},
      highlightedDates: weeklySchedulesState.dates,
    );
  }
}

class _PunctualityIndicator extends StatelessWidget {
  const _PunctualityIndicator({
    required this.score,
  });

  final double score;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 40.0),
      child: SizedBox(
        width: 325,
        child: AnimatedArcIndicator(
          score: 80,
          child: Center(
            child: Padding(
              padding:
                  const EdgeInsets.only(top: 52.0, right: 60.0, left: 60.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PunctualityScore(score: score),
                  SizedBox(height: 6.0),
                  _PunctualityComment(
                      comment: '성실도 점수 30점 올랐어요!\n약속을 잘 지키고 있네요'),
                  SizedBox(height: 6.0),
                  _Character(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AnimatedArcIndicator extends StatefulWidget {
  const AnimatedArcIndicator(
      {super.key, required this.score, required this.child});

  final double score;
  final Widget child;

  @override
  State<AnimatedArcIndicator> createState() => _AnimatedArcIndicatorState();
}

class _AnimatedArcIndicatorState extends State<AnimatedArcIndicator>
    with TickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation _animation;

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _animationController =
        AnimationController(duration: const Duration(seconds: 1), vsync: this);
    _animation = Tween<double>(begin: 0, end: widget.score / 100)
        .animate(_animationController);
    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          painter: ArcIndicator(
            strokeWidth: 16,
            progress: _animation.value,
          ),
          child: widget.child,
        );
      },
    );
  }
}

class _PunctualityScore extends StatelessWidget {
  const _PunctualityScore({
    required this.score,
  });

  final double score;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Text('${score.toInt()}점', style: textTheme.displaySmall);
  }
}

class _Character extends StatelessWidget {
  const _Character();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        height: 270.3,
        child: SvgPicture.asset(
          'characters/character.svg',
          package: 'assets',
        ));
  }
}

class _PunctualityComment extends StatelessWidget {
  const _PunctualityComment({
    required this.comment,
  });

  final String comment;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Text(
      comment,
      style: textTheme.bodySmall,
      textAlign: TextAlign.center,
    );
  }
}
