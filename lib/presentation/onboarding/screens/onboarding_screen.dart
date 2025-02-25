import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/presentation/onboarding/preparation_order/screens/preparation_order_form.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/cubit/preparation_name/preparation_name_cubit.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/screens/preparation_name_form.dart';
import 'package:on_time_front/presentation/onboarding/preparation_time/cubit/preparation_time_cubit.dart';
import 'package:on_time_front/presentation/onboarding/preparation_time/screens/preparation_time_form.dart';
import 'package:on_time_front/presentation/onboarding/schedule_spare_time/cubit/schedule_spare_time_cubit.dart';
import 'package:on_time_front/presentation/onboarding/schedule_spare_time/screens/schedule_spare_time_form.dart';
import 'package:on_time_front/presentation/onboarding/cubit/onboarding_cubit.dart';
import 'package:on_time_front/presentation/onboarding/preparation_order/cubit/preparation_order_cubit.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt.get<OnboardingCubit>(),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: OnboardingForm(),
      ),
    );
  }
}

class OnboardingForm extends StatefulWidget {
  const OnboardingForm({super.key});

  @override
  State<OnboardingForm> createState() => _OnboardingFormState();
}

class _OnboardingFormState extends State<OnboardingForm>
    with TickerProviderStateMixin {
  late PageController _pageViewController;
  late TabController _tabController;
  Duration spareTime = const Duration(minutes: 0);
  final int _numberOfPages = 4;
  final List<Type> _pageCubitTypes = [
    PreparationNameCubit,
    PreparationOrderCubit,
    PreparationTimeCubit,
    ScheduleSpareTimeCubit,
  ];

  @override
  void initState() {
    super.initState();
    _pageViewController = PageController();
    _tabController = TabController(length: _numberOfPages, vsync: this);
  }

  @override
  void dispose() {
    super.dispose();
    _pageViewController.dispose();
    _tabController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: MultiBlocProvider(
          providers: [
            BlocProvider<PreparationNameCubit>(
              create: (context) => PreparationNameCubit(
                onboardingCubit: context.read<OnboardingCubit>(),
              ),
            ),
            BlocProvider<PreparationOrderCubit>(
              create: (context) => PreparationOrderCubit(
                onboardingCubit: context.read<OnboardingCubit>(),
              ),
            ),
            BlocProvider<PreparationTimeCubit>(
              create: (context) => PreparationTimeCubit(
                onboardingCubit: context.read<OnboardingCubit>(),
              ),
            ),
            BlocProvider<ScheduleSpareTimeCubit>(
              create: (context) => ScheduleSpareTimeCubit(
                onboardingCubit: context.read<OnboardingCubit>(),
              ),
            ),
          ],
          child: Builder(builder: (context) {
            return Column(
              children: <Widget>[
                PageIndicator(
                  tabController: _tabController,
                  onUpdateCurrentPageIndex: _updateCurrentPageIndex,
                ),
                Expanded(
                  child: PageView(
                    physics: const NeverScrollableScrollPhysics(),
                    controller: _pageViewController,
                    onPageChanged: _handlePageViewChanged,
                    children: <Widget>[
                      PreparationNameForm(),
                      PreparationOrderForm(),
                      PreparationTimeForm(),
                      ScheduleSpareTimeForm(),
                    ],
                  ),
                ),
                SizedBox(
                    height: 58,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: context.select(
                              (OnboardingCubit cubit) => cubit.state.isValid)
                          ? () => _onNextPageButtonClicked(context)
                          : null,
                      child: const Text('다음'),
                    )),
              ],
            );
          }),
        ),
      ),
    );
  }

  Future<void> _onNextPageButtonClicked(BuildContext context) async {
    switch (_pageCubitTypes[_tabController.index]) {
      case const (PreparationNameCubit):
        context.read<PreparationNameCubit>().preparationSaved();
        break;
      case const (PreparationOrderCubit):
        context.read<PreparationOrderCubit>().preparationOrderSaved();
        break;
      case const (PreparationTimeCubit):
        context.read<PreparationTimeCubit>().preparationTimeSaved();
        break;
      case const (ScheduleSpareTimeCubit):
        context.read<ScheduleSpareTimeCubit>().spareTimeSaved();
        break;
    }
    if (_tabController.index < _numberOfPages - 1) {
      _updateCurrentPageIndex(_tabController.index + 1);
    } else {
      return await context.read<OnboardingCubit>().onboardingFormSubmitted();
    }
  }

  void _handlePageViewChanged(int currentPageIndex) {
    _tabController.index = currentPageIndex;
    setState(() {
      _tabController.index = currentPageIndex;
    });
  }

  void _updateCurrentPageIndex(int index) {
    if (index < 0) {
      context.pop();
      return;
    }
    _tabController.index = index;
    _pageViewController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }
}

class PageIndicator extends StatelessWidget {
  const PageIndicator({
    super.key,
    required this.tabController,
    required this.onUpdateCurrentPageIndex,
  });

  final TabController tabController;
  final void Function(int) onUpdateCurrentPageIndex;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    const double iconButtonSize = 32.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        SizedBox(
          width: iconButtonSize,
          height: iconButtonSize,
          child: IconButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              onUpdateCurrentPageIndex(tabController.index - 1);
            },
            icon: const Icon(
              Icons.arrow_left_rounded,
              size: 24.0,
            ),
          ),
        ),
        TabPageSelector(
          controller: tabController,
          color: colorScheme.surface,
          selectedColor: colorScheme.primary,
        ),
        SizedBox(
          width: iconButtonSize,
        )
      ],
    );
  }
}
