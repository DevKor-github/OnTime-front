import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/app/bloc/app_bloc.dart';
import 'package:on_time_front/presentation/calendar/bloc/monthly_schedules_bloc.dart';
import 'package:on_time_front/presentation/home/components/todays_schedule_tile.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/presentation/shared/components/calendar/centered_calendar_header.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:on_time_front/presentation/shared/components/arc_indicator.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';
import 'package:on_time_front/presentation/shared/theme/calendar_theme.dart';

class HomeScreenTmp extends StatefulWidget {
  const HomeScreenTmp({super.key});

  @override
  State<HomeScreenTmp> createState() => _HomeScreenTmpState();
}

class _HomeScreenTmpState extends State<HomeScreenTmp> {
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
    final colorScheme = Theme.of(context).colorScheme;

    return BlocProvider(
      create: (context) => getIt.get<MonthlySchedulesBloc>()
        ..add(MonthlySchedulesSubscriptionRequested(date: dateOfToday)),
      child: BlocBuilder<MonthlySchedulesBloc, MonthlySchedulesState>(
        builder: (context, state) {
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                Container(
                  color: colorScheme.primary,
                  padding: const EdgeInsets.only(top: 58.0),
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      _CharacterSection(score: score),
                      todaysScheduleOverlayBuilder(state),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.only(
                      top: 0.0, left: 16.0, right: 16.0, bottom: 24.0),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLowest,
                  ),
                  child: _MonthlySchedule(
                    monthlySchedulesState: state,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget todaysScheduleOverlayBuilder(MonthlySchedulesState state) {
    final theme = Theme.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    final todaySchedules = state.schedules[todayKey] ?? [];
    final todaySchedule =
        todaySchedules.isNotEmpty ? todaySchedules.first : null;

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.only(top: 49.0),
            child: Container(
              decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16))),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0) +
              EdgeInsets.only(bottom: 20.0),
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
                    AppLocalizations.of(context)!.todaysAppointments,
                    style: theme.textTheme.titleLarge,
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

class _MonthlySchedule extends StatelessWidget {
  const _MonthlySchedule({
    required this.monthlySchedulesState,
  });

  final MonthlySchedulesState monthlySchedulesState;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MonthlyScheduleHeader(),
        _MonthCalendar(
          monthlySchedulesState: monthlySchedulesState,
        ),
      ],
    );
  }
}

class _MonthlyScheduleHeader extends StatelessWidget {
  _MonthlyScheduleHeader();

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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Text(
            AppLocalizations.of(context)!.calendarTitle,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          Spacer(),
          TextButton(
            onPressed: () {
              context.go('/calendar');
            },
            child: Row(
              children: [
                Text(AppLocalizations.of(context)!.viewCalendar,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outlineVariant)),
                arrowRightSvg,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthCalendar extends StatefulWidget {
  const _MonthCalendar({required this.monthlySchedulesState});

  final MonthlySchedulesState monthlySchedulesState;

  @override
  State<_MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends State<_MonthCalendar> {
  late DateTime _focusedDay;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
  }

  void _onLeftArrowTap() {
    setState(() {
      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
    });
  }

  void _onRightArrowTap() {
    setState(() {
      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final calendarTheme = theme.extension<CalendarTheme>()!;

    if (widget.monthlySchedulesState.schedules.isEmpty) {
      if (widget.monthlySchedulesState.status ==
          MonthlySchedulesStatus.loading) {
        return CircularProgressIndicator();
      } else if (widget.monthlySchedulesState.status !=
          MonthlySchedulesStatus.success) {
        return const SizedBox();
      }
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
      ),
      child: TableCalendar(
        locale: Localizations.localeOf(context).toString(),
        eventLoader: (day) {
          day = DateTime(day.year, day.month, day.day);
          return widget.monthlySchedulesState.schedules[day] ?? [];
        },
        focusedDay: _focusedDay,
        firstDay: DateTime(2024, 1, 1),
        lastDay: DateTime(2025, 12, 31),
        calendarFormat: CalendarFormat.month,
        headerStyle: calendarTheme.headerStyle,
        daysOfWeekStyle: calendarTheme.daysOfWeekStyle,
        daysOfWeekHeight: 40,
        calendarStyle: calendarTheme.calendarStyle,
        onDaySelected: (selectedDay, focusedDay) {
          // Handle day selection if needed
        },
        onPageChanged: (focusedDay) {
          setState(() {
            _focusedDay = focusedDay;
          });
          context.read<MonthlySchedulesBloc>().add(MonthlySchedulesMonthAdded(
              date:
                  DateTime(focusedDay.year, focusedDay.month, focusedDay.day)));
        },
        calendarBuilders: CalendarBuilders(
          headerTitleBuilder: (context, date) {
            return CenteredCalendarHeader(
              focusedMonth: date,
              onLeftArrowTap: _onLeftArrowTap,
              onRightArrowTap: _onRightArrowTap,
              titleTextStyle: calendarTheme.headerStyle.titleTextStyle,
              leftIcon: calendarTheme.headerStyle.leftChevronIcon,
              rightIcon: calendarTheme.headerStyle.rightChevronIcon,
            );
          },
          todayBuilder: (context, day, focusedDay) => Container(
            margin: const EdgeInsets.all(4.0),
            alignment: Alignment.center,
            decoration: calendarTheme.todayDecoration,
            child: Text(
              day.day.toString(),
              style: textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CharacterSection extends StatelessWidget {
  const _CharacterSection({
    required this.score,
  });

  final double score;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 40.0) +
          EdgeInsets.symmetric(horizontal: 17.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 27.0),
            child: _Slogan(comment: AppLocalizations.of(context)!.slogan),
          ),
          _Character(),
        ],
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

class _Character extends StatelessWidget {
  const _Character();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 176,
      height: 247.57,
      child: SvgPicture.asset(
        'characters/character.svg',
        package: 'assets',
      ),
    );
  }
}

class _Slogan extends StatelessWidget {
  const _Slogan({
    required this.comment,
  });

  final String comment;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Text(
      comment,
      style: textTheme.titleExtraLarge.copyWith(color: colorScheme.onPrimary),
    );
  }
}
