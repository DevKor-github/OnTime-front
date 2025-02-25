import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/schedule_form/schedule_form_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/compoenent/top_bar.dart';
import 'package:on_time_front/presentation/schedule_create/compoenent/schedule_name_form.dart';
import 'package:on_time_front/presentation/schedule_create/compoenent/schedule_place_moving_time_form.dart';
import 'package:on_time_front/presentation/schedule_create/compoenent/schedule_spare_and_preparing_time_form.dart';
import 'package:on_time_front/presentation/schedule_create/compoenent/schedule_time_form.dart';
import 'package:on_time_front/presentation/shared/components/step_progress.dart';

class ScheduleMultiPageForm extends StatefulWidget {
  const ScheduleMultiPageForm({super.key, this.onSaved});

  final void Function()? onSaved;

  @override
  State<ScheduleMultiPageForm> createState() => _ScheduleMultiPageFormState();
}

class _ScheduleMultiPageFormState extends State<ScheduleMultiPageForm>
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
    return BlocBuilder<ScheduleFormBloc, ScheduleFormState>(
      builder: (context, state) {
        if (state.status == ScheduleFormStatus.error) {
          return const Text('Error');
        } else if (state.status == ScheduleFormStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            TopBar(
              onNextPAgeButtonClicked: () => _onNextPageButtonClicked(context),
              onPreviousPageButtonClicked: _onPreviousPageButtonClicked,
            ),
            StepProgress(
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
                          ScheduleFormScheduleNameChanged(scheduleName: value));
                    }),
                ScheduleTimeForm(
                  formKey: formKeys[1],
                  initalValue: state,
                  onScheduleTimeSaved: (value) {
                    context.read<ScheduleFormBloc>().add(
                        ScheduleFormScheduleTimeChanged(scheduleTime: value));
                  },
                  onScheduleDateSaved: (value) {
                    context.read<ScheduleFormBloc>().add(
                        ScheduleFormScheduleDateChanged(scheduleDate: value));
                  },
                ),
                SchedulePlaceMovingTimeForm(
                    formKey: formKeys[2],
                    initalValue: state,
                    onPlaceNameSaved: (value) {
                      context
                          .read<ScheduleFormBloc>()
                          .add(ScheduleFormPlaceNameChanged(placeName: value));
                    },
                    onMovingTimeSaved: (value) {
                      context
                          .read<ScheduleFormBloc>()
                          .add(ScheduleFormMoveTimeChanged(moveTime: value));
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
    );
  }

  void _onNextPageButtonClicked(BuildContext context) {
    formKeys[_tabController.index].currentState?.save();
    if (_tabController.index < _tabController.length - 1) {
      _updateCurrentPageIndex(_tabController.index + 1);
    } else {
      widget.onSaved?.call();
      context.go('/home');
    }
  }

  void _onPreviousPageButtonClicked() {
    if (_tabController.index > 0) {
      _updateCurrentPageIndex(_tabController.index - 1);
    } else {
      context.go('/home');
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
