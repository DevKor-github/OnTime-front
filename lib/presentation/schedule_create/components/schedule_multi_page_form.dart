import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/schedule_form_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/components/top_bar.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_date_time/cubit/schedule_date_time_cubit.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_date_time/screens/schedule_date_time_form.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_name/screens/schedule_name_form.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_name/cubit/schedule_name_cubit.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_place_moving_time.dart/cubit/schedule_place_moving_time_cubit.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_place_moving_time.dart/screens/schedule_place_moving_time_form.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/cubit/schedule_form_spare_time_cubit.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/screens/schedule_spare_and_preparing_time_form.dart';
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
  final List<Type> _pageCubitTypes = [
    ScheduleNameCubit,
    ScheduleDateTimeCubit,
    SchedulePlaceMovingTimeCubit,
    ScheduleFormSpareTimeCubit,
  ];
  late List<GlobalKey<FormState>> formKeys;

  @override
  void initState() {
    _pageViewController = PageController();
    _tabController = TabController(length: _pageCubitTypes.length, vsync: this);
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

        return MultiBlocProvider(
          providers: [
            BlocProvider<ScheduleNameCubit>(
              create: (context) => ScheduleNameCubit(
                scheduleFormBloc: context.read<ScheduleFormBloc>(),
              ),
            ),
            BlocProvider(
              create: (context) => ScheduleDateTimeCubit(
                scheduleFormBloc: context.read<ScheduleFormBloc>(),
              ),
            ),
            BlocProvider(
              create: (context) => SchedulePlaceMovingTimeCubit(
                scheduleFormBloc: context.read<ScheduleFormBloc>(),
              ),
            ),
            BlocProvider(
              create: (context) => ScheduleFormSpareTimeCubit(
                scheduleFormBloc: context.read<ScheduleFormBloc>(),
              ),
            ),
          ],
          child: Builder(builder: (context) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Column(
                children: [
                  TopBar(
                    onNextPageButtonClicked: state.isValid
                        ? () => _onNextPageButtonClicked(context)
                        : null,
                    // 버튼 활성화 판별
                    isNextButtonEnabled: state.isValid,
                    onPreviousPageButtonClicked: _onPreviousPageButtonClicked,
                  ),
                  StepProgress(
                    currentStep: _tabController.index,
                    totalSteps: _tabController.length,
                    singleLine: true,
                  ),
                  Expanded(
                      child: PageView(
                    physics: const NeverScrollableScrollPhysics(),
                    controller: _pageViewController,
                    onPageChanged: _handlePageViewChanged,
                    children: [
                      ScheduleNameForm(),
                      ScheduleDateTimeForm(),
                      SchedulePlaceMovingTimeForm(),
                      ScheduleSpareAndPreparingTimeForm(),
                    ],
                  )),
                ],
              ),
            );
          }),
        );
      },
    );
  }

  void _onNextPageButtonClicked(BuildContext context) {
    switch (_pageCubitTypes[_tabController.index]) {
      case const (ScheduleNameCubit):
        context.read<ScheduleNameCubit>().scheduleNameSubmitted();
        break;
      case const (ScheduleDateTimeCubit):
        context.read<ScheduleDateTimeCubit>().scheduleDateTimeSubmitted();
        break;
      case const (SchedulePlaceMovingTimeCubit):
        context
            .read<SchedulePlaceMovingTimeCubit>()
            .schedulePlaceMovingTimeSubmitted();
        break;
      case const (ScheduleFormSpareTimeCubit):
        context.read<ScheduleFormSpareTimeCubit>().scheduleSpareTimeSubmitted();
        break;
    }
    if (_tabController.index < _tabController.length - 1) {
      _updateCurrentPageIndex(_tabController.index + 1);
    } else {
      widget.onSaved?.call();
      Navigator.of(context).pop(); // Close the form
      // context.go('/home');
    }
  }

  void _onPreviousPageButtonClicked() {
    if (_tabController.index > 0) {
      _updateCurrentPageIndex(_tabController.index - 1);
    } else {
      Navigator.of(context).pop(); // Close the form
      // context.go('/home');
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
