import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/schedule_form/schedule_form_bloc.dart';
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
        child: BlocProvider<ScheduleFormBloc>(
          create: (context) =>
              getIt.get<ScheduleFormBloc>()..add(ScheduleFormCreateRequested()),
          child: BlocBuilder<ScheduleFormBloc, ScheduleFormState>(
            builder: (context, state) {
              return Column(
                children: [
                  TopBar(
                    onNextPAgeButtonClicked: () =>
                        _onNextPageButtonClicked(context),
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
                          initalValue: state,
                          onScheduleNameSaved: (value) {
                            context.read<ScheduleFormBloc>().add(
                                ScheduleFormScheduleNameChanged(
                                    scheduleName: value));
                          }),
                      ScheduleTimeForm(
                        formKey: formKeys[1],
                        initalValue: state,
                        onScheduleTimeSaved: (value) {
                          context.read<ScheduleFormBloc>().add(
                              ScheduleFormScheduleTimeChanged(
                                  scheduleTime: value));
                        },
                        onScheduleDateSaved: (value) {
                          context.read<ScheduleFormBloc>().add(
                              ScheduleFormScheduleDateChanged(
                                  scheduleDate: value));
                        },
                      ),
                      SchedulePlaceMovingTimeForm(
                          formKey: formKeys[2],
                          initalValue: state,
                          onPlaceNameSaved: (value) {
                            context.read<ScheduleFormBloc>().add(
                                ScheduleFormPlaceNameChanged(placeName: value));
                          },
                          onMovingTimeSaved: (value) {
                            context.read<ScheduleFormBloc>().add(
                                ScheduleFormMoveTimeChanged(moveTime: value));
                          }),
                      ScheduleSpareAndPreparingTimeForm(
                          formKey: formKeys[3],
                          initalValue: state,
                          onSpareTimeSaved: (value) {
                            context.read<ScheduleFormBloc>().add(
                                ScheduleFormScheduleSpareTimeChanged(
                                    scheduleSpareTime: value));
                          }),
                    ],
                  )),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _onNextPageButtonClicked(BuildContext context) {
    formKeys[_tabController.index].currentState?.save();
    if (_tabController.index < _tabController.length - 1) {
      _updateCurrentPageIndex(_tabController.index + 1);
    } else {
      context.read<ScheduleFormBloc>().add(ScheduleFormSaved());
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
