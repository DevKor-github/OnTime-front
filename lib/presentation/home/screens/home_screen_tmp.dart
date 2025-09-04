import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/app/bloc/app_bloc.dart';
import 'package:on_time_front/presentation/calendar/bloc/monthly_schedules_bloc.dart';
import 'package:on_time_front/presentation/home/components/todays_schedule_tile.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/presentation/shared/components/arc_indicator.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';
import 'package:on_time_front/presentation/home/components/month_calendar.dart';

/// Wrapper widget that provides the BlocProvider for HomeScreenTmp
class HomeScreenTmp extends StatelessWidget {
  const HomeScreenTmp({super.key});

  @override
  Widget build(BuildContext context) {
    final dateOfToday = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day, 0, 0, 0);

    return BlocProvider(
      create: (context) => getIt.get<MonthlySchedulesBloc>()
        ..add(MonthlySchedulesSubscriptionRequested(date: dateOfToday)),
      child: BlocBuilder<MonthlySchedulesBloc, MonthlySchedulesState>(
        builder: (context, state) {
          return HomeScreenContent(state: state);
        },
      ),
    );
  }
}

/// The actual home screen content that can be tested independently
class HomeScreenContent extends StatelessWidget {
  const HomeScreenContent({
    super.key,
    required this.state,
    this.userScore,
  });

  final MonthlySchedulesState state;
  final double? userScore;

  @override
  Widget build(BuildContext context) {
    final double score = userScore ??
        context.select((AppBloc bloc) =>
            bloc.state.user.mapOrNull((user) => user.score) ?? -1);
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          Container(
            color: colorScheme.primary,
            padding: const EdgeInsets.only(top: 58.0),
            child: Column(
              children: [
                _CharacterSection(score: score),
                _TodaysScheduleOverlay(state: state),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.only(
                top: 0.0, left: 16.0, right: 16.0, bottom: 24.0),
            decoration: BoxDecoration(
              color: colorScheme.surface,
            ),
            child: _MonthlySchedule(
              monthlySchedulesState: state,
            ),
          ),
        ],
      ),
    );
  }
}

class _TodaysScheduleOverlay extends StatelessWidget {
  const _TodaysScheduleOverlay({
    required this.state,
  });

  final MonthlySchedulesState state;

  @override
  Widget build(BuildContext context) {
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
                color: colorScheme.surface,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
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
            elevation: 6,
            shadowColor: Colors.black.withValues(alpha: 0.4),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.todaysAppointments,
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
        MonthCalendar(
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

// Moved MonthCalendar into components/month_calendar.dart

class _CharacterSection extends StatelessWidget {
  const _CharacterSection({
    required this.score,
  });

  final double score;

  @override
  Widget build(BuildContext context) {
    return Image.asset('home_banner.png', package: 'assets');
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
      height: 130,
      child: SvgPicture.asset(
        'characters/half_character.svg',
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
