import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/presentation/schedule_create/compoenent/top_bar.dart';
import 'package:on_time_front/presentation/schedule_create/screens/schedule_name_form.dart';
import 'package:on_time_front/presentation/schedule_create/screens/schedule_place_moving_time_form.dart';
import 'package:on_time_front/presentation/schedule_create/screens/schedule_spare_and_preparing_time_form.dart';
import 'package:on_time_front/presentation/schedule_create/screens/schedule_time_form.dart';
import 'package:on_time_front/presentation/shared/components/progress_bar.dart';

class ScheduleCreateScreen extends StatefulWidget {
  const ScheduleCreateScreen({super.key});

  @override
  State<ScheduleCreateScreen> createState() => _ScheduleCreateScreenState();
}

class _ScheduleCreateScreenState extends State<ScheduleCreateScreen>
    with TickerProviderStateMixin {
  late PageController _pageViewController;
  late TabController _tabController;
  late List<GlobalKey<FormState>> formKeys;
  ScheduleFormData _scheduleFormData = ScheduleFormData();

  @override
  void initState() {
    _pageViewController = PageController();
    _tabController = TabController(length: 4, vsync: this);
    formKeys =
        List.generate(_tabController.length, (index) => GlobalKey<FormState>());
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: SafeArea(
        child: Column(
          children: [
            TopBar(
              tabController: _tabController,
              onNextPAgeButtonClicked: _onNextPageButtonClicked,
              onPreviousPageButtonClicked: _onPreviousPageButtonClicked,
            ),
            ProgressBar(
              tabController: _tabController,
            ),
            Expanded(
              child: PageView(
                physics: const NeverScrollableScrollPhysics(),
                controller: _pageViewController,
                onPageChanged: _handlePageViewChanged,
                children: [
                  ScheduleNameForm(
                      formKey: formKeys[0],
                      initalValue: _scheduleFormData,
                      onSaved: (value) {
                        _scheduleFormData = value;
                      }),
                  ScheduleTimeForm(
                      formKey: formKeys[1],
                      initalValue: _scheduleFormData,
                      onSaved: (value) {
                        _scheduleFormData = value;
                      }),
                  SchedulePlaceMovingTimeForm(
                      formKey: formKeys[2],
                      initalValue: _scheduleFormData,
                      onSaved: (value) {
                        _scheduleFormData = value;
                      }),
                  ScheduleSpareAndPreparingTimeForm(
                      formKey: formKeys[3],
                      initalValue: _scheduleFormData,
                      onSaved: (value) {
                        _scheduleFormData = value;
                      }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onNextPageButtonClicked() {
    formKeys[_tabController.index].currentState?.save();
    if (_tabController.index < _tabController.length - 1) {
      _updateCurrentPageIndex(_tabController.index + 1);
    } else {
      context.go('/home');
    }
  }

  void _onPreviousPageButtonClicked() {
    if (_tabController.index > 0) {
      _updateCurrentPageIndex(_tabController.index - 1);
    }
  }

  void _handlePageViewChanged(int currentPageIndex) {
    _tabController.index = currentPageIndex;
    setState(() {
      _tabController.index = currentPageIndex;
    });
  }

  void _updateCurrentPageIndex(int index) {
    _tabController.index = index;
    _pageViewController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }
}

class ScheduleFormData {
  final String? id;
  final String? placeName;
  final String? scheduleName;
  final DateTime? scheduleTime;
  final Duration? moveTime;
  final bool? isChanged;
  final Duration? scheduleSpareTime;
  final String? scheduleNote;
  final Duration? spareTime;

  ScheduleFormData({
    this.id,
    this.placeName,
    this.scheduleName,
    this.scheduleTime,
    this.moveTime,
    this.isChanged,
    this.scheduleSpareTime,
    this.scheduleNote,
    this.spareTime,
  });

  ScheduleFormData copyWith({
    String? id,
    String? userId,
    String? placeName,
    String? scheduleName,
    DateTime? scheduleTime,
    Duration? moveTime,
    bool? isChanged,
    bool? isStarted,
    Duration? scheduleSpareTime,
    String? scheduleNote,
    Duration? spareTime,
  }) {
    return ScheduleFormData(
      id: id ?? this.id,
      placeName: placeName ?? this.placeName,
      scheduleName: scheduleName ?? this.scheduleName,
      scheduleTime: scheduleTime ?? this.scheduleTime,
      moveTime: moveTime ?? this.moveTime,
      isChanged: isChanged ?? this.isChanged,
      scheduleSpareTime: scheduleSpareTime ?? this.scheduleSpareTime,
      scheduleNote: scheduleNote ?? this.scheduleNote,
      spareTime: spareTime ?? this.spareTime,
    );
  }
}
