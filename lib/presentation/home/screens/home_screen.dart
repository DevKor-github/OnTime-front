import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/repositories/schedule_repository.dart';
import 'package:on_time_front/presentation/home/components/home_app_bar.dart';
import 'package:on_time_front/presentation/home/components/todays_schedule_tile.dart';
import 'package:on_time_front/presentation/home/components/week_calendar.dart';
import 'package:on_time_front/presentation/home/view_models/home_view_model.dart';
import 'package:on_time_front/presentation/shared/components/arc_indicator.dart';
import 'package:on_time_front/presentation/shared/components/bottom_navigation_bar.dart';
import 'package:uuid/uuid.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
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
    _overlayEntry?.remove();
    _overlayEntry = OverlayEntry(
        builder: (context) => todaysScheduleOverlayBuilder(context));
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_overlayEntry != null) {
        Overlay.of(context).insert(_overlayEntry!);
      }
    });
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..forward();
    _animation = _animationController.drive(
      Tween<double>(begin: 0, end: 0.7),
    );
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
    final schedules = ref.watch(homeViewModelProvider(dateOfToday));
    final homeViewModel =
        ref.watch(homeViewModelProvider(dateOfToday).notifier);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: HomeAppBar(),
      body: Column(
        children: [
          Padding(
            key: _overlayKey,
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
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
                              Text('70점', style: theme.textTheme.displaySmall),
                              SizedBox(height: 6.0),
                              Text(
                                '성실도 점수 30점 올랐어요!\n약속을 잘 지키고 있네요',
                                style: theme.textTheme.bodySmall,
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 6.0),
                              SizedBox(
                                  height: 270.3,
                                  child: Image.asset('assets/character.png')),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
          ),
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                color: Color(0xffF3F5FF),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.only(top: 71.0, left: 16.0, right: 16.0),
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
                                      color: theme.colorScheme.outlineVariant)),
                              arrowRightSvg,
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 23.0),
                    switch (schedules) {
                      AsyncValue(:final error?) => Text('$error 에러가 발생했습니다'),
                      AsyncValue(:final valueOrNull?) => WeekCalendar(
                          date: DateTime.now(),
                          onDateSelected: (date) {},
                          highlightedDates:
                              homeViewModel.getDatesOfSchedule(valueOrNull)),
                      _ => SizedBox(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                                theme.colorScheme.primary),
                          ),
                        ),
                    },
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
          final scheduleRepository = getIt.get<ScheduleRepository>();
          scheduleRepository.createSchedule(
            ScheduleEntity(
              id: Uuid().v7(),
              scheduleTime: dateOfToday.add(Duration(days: -2, hours: 10)),
              scheduleName: '약속',
              moveTime: Duration(minutes: 10),
              isChanged: false,
              isStarted: false,
              scheduleSpareTime: Duration(minutes: 10),
              scheduleNote: '',
              userId: '1',
              place: PlaceEntity(
                id: Uuid().v7(),
                placeName: '장소',
              ),
            ),
          );
        },
        child: Icon(Icons.add),
      ),
      bottomNavigationBar: CustomBottomNavigationBar(),
    );
  }

  Widget todaysScheduleOverlayBuilder(BuildContext context) {
    final keyContext = _overlayKey.currentContext;
    final theme = Theme.of(context);
    if (keyContext != null) {
      final RenderBox renderBox = keyContext.findRenderObject() as RenderBox;
      final Offset offset = renderBox.localToGlobal(Offset.zero);
      return Positioned(
          top: offset.dy + renderBox.size.height - 117,
          left: 16,
          right: 16,
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
                    schedule: null,
                  )
                ],
              ),
            ),
          ));
    }
    return Container();
  }
}
