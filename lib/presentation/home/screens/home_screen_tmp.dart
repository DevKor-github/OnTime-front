import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/app/bloc/auth/auth_bloc.dart';
import 'package:on_time_front/presentation/calendar/bloc/monthly_schedules_bloc.dart';
import 'package:on_time_front/presentation/home/components/todays_schedule_tile.dart';
import 'package:on_time_front/presentation/home/utils/today_tile_navigation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/presentation/shared/components/arc_indicator.dart';
import 'package:on_time_front/presentation/home/components/month_calendar.dart';
import 'package:on_time_front/presentation/app/bloc/schedule/schedule_bloc.dart';
import 'package:on_time_front/presentation/shared/router/route_arguments.dart';

/// Wrapper widget that provides the BlocProvider for HomeScreenTmp
class HomeScreenTmp extends StatelessWidget {
  const HomeScreenTmp({super.key});

  @override
  Widget build(BuildContext context) {
    final dateOfToday = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      0,
      0,
      0,
    );

    return BlocProvider(
      create: (context) =>
          getIt.get<MonthlySchedulesBloc>()
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
  const HomeScreenContent({super.key, required this.state, this.userScore});

  final MonthlySchedulesState state;
  final double? userScore;

  @override
  Widget build(BuildContext context) {
    final double score =
        userScore ??
        context.select((AuthBloc bloc) => bloc.state.user.scoreOrNull ?? -1);
    final colorScheme = Theme.of(context).colorScheme;

    return BlocListener<ScheduleBloc, ScheduleState>(
      listenWhen: (previous, current) {
        return previous.status != ScheduleStatus.started &&
            current.status == ScheduleStatus.started;
      },
      listener: (context, scheduleState) {
        context.go('/scheduleStart');
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final metrics = _HomeLayoutMetrics.fromConstraints(
            constraints: constraints,
            textScale: MediaQuery.textScalerOf(context).scale(1),
            safeAreaTop: MediaQuery.paddingOf(context).top,
          );

          return Column(
            children: [
              SizedBox(
                height: metrics.topSectionHeight,
                child: ColoredBox(
                  color: colorScheme.primary,
                  child: Column(
                    children: [
                      SizedBox(height: metrics.safeAreaGap),
                      Expanded(
                        child: ColoredBox(
                          color: colorScheme.primary,
                          child: Column(
                            children: [
                              SizedBox(height: metrics.heroTopPadding),
                              _CharacterSection(
                                score: score,
                                height: metrics.bannerHeight,
                                topPadding: 8,
                              ),
                              _TodaysScheduleOverlay(metrics: metrics),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  padding: EdgeInsets.only(
                    left: metrics.sectionHorizontalPadding,
                    right: metrics.sectionHorizontalPadding,
                  ),
                  decoration: BoxDecoration(color: colorScheme.surface),
                  child: _MonthlySchedule(
                    monthlySchedulesState: state,
                    metrics: metrics,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TodaysScheduleOverlay extends StatelessWidget {
  const _TodaysScheduleOverlay({required this.metrics});

  final _HomeLayoutMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return BlocBuilder<ScheduleBloc, ScheduleState>(
      builder: (context, scheduleState) {
        final todaySchedule =
            scheduleState.status == ScheduleStatus.notExists ||
                scheduleState.status == ScheduleStatus.initial
            ? null
            : scheduleState.schedule;
        final hasSchedule = todaySchedule != null;
        final target = resolveTodayTileNavigationTarget(
          scheduleStatus: scheduleState.status,
          hasSchedule: hasSchedule,
        );

        return SizedBox(
          height: metrics.todayOverlayHeight,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: metrics.todayHeroOverlap,
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  key: const Key('today_background_surface'),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  left: metrics.cardHorizontalPadding,
                  right: metrics.cardHorizontalPadding,
                ),
                child: Material(
                  key: const Key('today_schedule_card'),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  color: theme.colorScheme.surface,
                  elevation: 6,
                  shadowColor: Colors.black.withValues(alpha: 0.4),
                  child: Padding(
                    padding: EdgeInsets.all(metrics.todayCardPadding),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.todaysAppointments,
                          style:
                              (metrics.compact
                                      ? theme.textTheme.titleSmall
                                      : theme.textTheme.titleMedium)
                                  ?.copyWith(
                                    height: metrics.compact ? 22 / 16 : 22 / 18,
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: metrics.todayTitleGap),
                        TodaysScheduleTile(
                          key: const Key('today_schedule_tile'),
                          schedule: todaySchedule,
                          compact: metrics.compact,
                          onTap: target == null
                              ? null
                              : () => context.go(
                                  target.path,
                                  extra: target.extra,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MonthlySchedule extends StatelessWidget {
  const _MonthlySchedule({
    required this.monthlySchedulesState,
    required this.metrics,
  });

  final MonthlySchedulesState monthlySchedulesState;
  final _HomeLayoutMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MonthlyScheduleHeader(metrics: metrics),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: MonthCalendar(
              key: const Key('home_month_calendar'),
              monthlySchedulesState: monthlySchedulesState,
              rowHeight: metrics.calendarRowHeight,
              daysOfWeekHeight: metrics.calendarDaysOfWeekHeight,
              contentPadding: EdgeInsets.only(
                left: metrics.calendarPadding,
                right: metrics.calendarPadding,
                bottom: metrics.calendarPadding + metrics.calendarFabClearance,
              ),
              onDateSelected: (date) {
                context.go(calendarRouteLocation(date), extra: date);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _MonthlyScheduleHeader extends StatelessWidget {
  _MonthlyScheduleHeader({required this.metrics});

  final _HomeLayoutMetrics metrics;

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
    return SizedBox(
      height: metrics.monthlyHeaderHeight,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: metrics.calendarPadding),
        child: Row(
          children: [
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.calendarTitle,
                style:
                    (metrics.compact
                            ? theme.textTheme.titleMedium
                            : theme.textTheme.titleLarge)
                        ?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () {
                context.go('/calendar');
              },
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: EdgeInsets.symmetric(
                  horizontal: metrics.compact ? 4.0 : 8.0,
                  vertical: metrics.compact ? 4.0 : 8.0,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppLocalizations.of(context)!.viewCalendar,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outlineVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  arrowRightSvg,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Moved MonthCalendar into components/month_calendar.dart

class _CharacterSection extends StatelessWidget {
  const _CharacterSection({
    required this.score,
    required this.height,
    required this.topPadding,
  });

  final double score;
  final double height;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Padding(
        padding: EdgeInsets.only(top: topPadding),
        child: Image.asset(
          key: const Key('home_banner'),
          'home_banner.png',
          package: 'assets',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _HomeLayoutMetrics {
  const _HomeLayoutMetrics({
    required this.compact,
    required this.safeAreaGap,
    required this.heroTopPadding,
    required this.bannerHeight,
    required this.todayOverlayHeight,
    required this.todayHeroOverlap,
    required this.todayCardPadding,
    required this.todayTitleGap,
    required this.cardHorizontalPadding,
    required this.sectionHorizontalPadding,
    required this.sectionBottomPadding,
    required this.monthlyHeaderHeight,
    required this.calendarRowHeight,
    required this.calendarDaysOfWeekHeight,
    required this.calendarPadding,
    required this.calendarFabClearance,
  });

  final bool compact;
  final double safeAreaGap;
  final double heroTopPadding;
  final double bannerHeight;
  final double todayOverlayHeight;
  final double todayHeroOverlap;
  final double todayCardPadding;
  final double todayTitleGap;
  final double cardHorizontalPadding;
  final double sectionHorizontalPadding;
  final double sectionBottomPadding;
  final double monthlyHeaderHeight;
  final double calendarRowHeight;
  final double calendarDaysOfWeekHeight;
  final double calendarPadding;
  final double calendarFabClearance;

  double get topSectionHeight =>
      safeAreaGap + heroTopPadding + bannerHeight + todayOverlayHeight;

  factory _HomeLayoutMetrics.fromConstraints({
    required BoxConstraints constraints,
    required double textScale,
    required double safeAreaTop,
  }) {
    final height = constraints.maxHeight.isFinite
        ? constraints.maxHeight
        : 800.0;
    final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 390.0;
    final heightPressure = (1 - ((height - 640) / 204)).clamp(0.0, 1.0);
    final widthPressure = width <= 380 ? 1.0 : 0.0;
    final textPressure = ((textScale - 1) / 0.3).clamp(0.0, 1.0);
    final pressure = math.max(
      heightPressure,
      math.max(widthPressure, textPressure),
    );

    double scale(double regular, double dense) {
      return regular + ((dense - regular) * pressure);
    }

    final safeAreaGap = safeAreaTop > 0 ? safeAreaTop + 4 : 0.0;
    final heroTopPadding = safeAreaTop > 0 ? 0.0 : scale(43, 18);
    const bannerAspectRatio = 1170 / 402;
    final fullWidthBannerHeight = width / bannerAspectRatio;
    final maxBannerHeight = math.min(scale(180, 124), height * 0.22);
    final bannerHeight = math.min(fullWidthBannerHeight, maxBannerHeight);
    final todayOverlayHeight = scale(137, 137);
    final todayHeroOverlap = scale(53, todayOverlayHeight / 2);
    final sectionBottomPadding = scale(24, 4);
    final monthlyHeaderHeight = scale(40, 28);
    final calendarDaysOfWeekHeight = scale(40, 22);
    final calendarPadding = scale(16, 4);
    final calendarFabClearance = scale(28, 20);
    const calendarHeaderHeight = 72.0;
    final calendarAvailableHeight =
        height -
        safeAreaGap -
        heroTopPadding -
        bannerHeight -
        todayOverlayHeight -
        sectionBottomPadding -
        monthlyHeaderHeight;
    final calendarRowHeight =
        ((calendarAvailableHeight -
                    (calendarPadding * 2) -
                    calendarDaysOfWeekHeight -
                    calendarHeaderHeight) /
                6)
            .clamp(28.0, 50.0);

    return _HomeLayoutMetrics(
      compact: pressure > 0.2,
      safeAreaGap: safeAreaGap,
      heroTopPadding: heroTopPadding,
      bannerHeight: bannerHeight,
      todayOverlayHeight: todayOverlayHeight,
      todayHeroOverlap: todayHeroOverlap,
      todayCardPadding: scale(20, 8),
      todayTitleGap: scale(21, 6),
      cardHorizontalPadding: 16,
      sectionHorizontalPadding: scale(16, 8),
      sectionBottomPadding: sectionBottomPadding,
      monthlyHeaderHeight: monthlyHeaderHeight,
      calendarRowHeight: calendarRowHeight,
      calendarDaysOfWeekHeight: calendarDaysOfWeekHeight,
      calendarPadding: calendarPadding,
      calendarFabClearance: calendarFabClearance,
    );
  }
}

class AnimatedArcIndicator extends StatefulWidget {
  const AnimatedArcIndicator({
    super.key,
    required this.score,
    required this.child,
  });

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
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0,
      end: widget.score / 100,
    ).animate(_animationController);
    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          painter: ArcIndicator(strokeWidth: 16, progress: _animation.value),
          child: widget.child,
        );
      },
    );
  }
}
