import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/presentation/recurring/recurrence_components.dart';
import 'package:on_time_front/presentation/onboarding/preparation_order/screens/preparation_order_form.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/cubit/preparation_name/preparation_name_cubit.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/screens/preparation_name_form.dart';
import 'package:on_time_front/presentation/onboarding/preparation_time/cubit/preparation_time_cubit.dart';
import 'package:on_time_front/presentation/onboarding/preparation_time/screens/preparation_time_form.dart';
import 'package:on_time_front/presentation/onboarding/schedule_spare_time/cubit/schedule_spare_time_cubit.dart';
import 'package:on_time_front/presentation/onboarding/schedule_spare_time/screens/schedule_spare_time_form.dart';
import 'package:on_time_front/presentation/onboarding/cubit/onboarding_cubit.dart';
import 'package:on_time_front/presentation/onboarding/preparation_order/cubit/preparation_order_cubit.dart';
import 'package:on_time_front/presentation/shared/components/modal_wide_button.dart';
import 'package:on_time_front/presentation/shared/components/two_action_dialog.dart';
import 'package:on_time_front/l10n/app_localizations.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt.get<OnboardingCubit>(),
      child: const RefreshTheme(
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          body: _OnboardingForm(),
        ),
      ),
    );
  }
}

class _OnboardingForm extends StatefulWidget {
  const _OnboardingForm();

  @override
  State<_OnboardingForm> createState() => _OnboardingFormState();
}

class _OnboardingFormState extends State<_OnboardingForm>
    with TickerProviderStateMixin {
  late PageController _pageViewController;
  late TabController _tabController;
  bool _isSubmitting = false;
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
    _tabController = TabController(length: _pageCubitTypes.length, vsync: this);
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
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          13 + MediaQuery.viewInsetsOf(context).bottom,
        ),
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
          child: Builder(
            builder: (context) {
              return Column(
                children: <Widget>[
                  _AppBar(
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
                  if (MediaQuery.viewInsetsOf(context).bottom == 0)
                    SizedBox(
                      height: 58,
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                        ),
                        onPressed:
                            !_isSubmitting &&
                                context.select(
                                  (OnboardingCubit cubit) =>
                                      cubit.state.isValid,
                                )
                            ? () => _onNextPageButtonClicked(context)
                            : null,
                        child: _isSubmitting
                            ? const SizedBox.square(
                                dimension: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(AppLocalizations.of(context)!.next),
                      ),
                    ),
                ],
              );
            },
          ),
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
    if (_tabController.index < _tabController.length - 1) {
      _updateCurrentPageIndex(_tabController.index + 1);
    } else {
      setState(() {
        _isSubmitting = true;
      });
      try {
        await context.read<OnboardingCubit>().onboardingFormSubmitted();
      } catch (_) {
        if (!context.mounted) return;
        final l10n = AppLocalizations.of(context)!;
        await showTwoActionDialog(
          context,
          config: TwoActionDialogConfig(
            title: l10n.error,
            primaryAction: DialogActionConfig(
              label: l10n.ok,
              variant: ModalWideButtonVariant.destructive,
            ),
          ),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
        }
      }
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

class _AppBar extends StatelessWidget {
  const _AppBar({
    required this.tabController,
    required this.onUpdateCurrentPageIndex,
  });

  final TabController tabController;
  final void Function(int) onUpdateCurrentPageIndex;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 39,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -8,
          top: -4,
          child: SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: () =>
                  onUpdateCurrentPageIndex(tabController.index - 1),
              icon: SvgPicture.asset(
                'chevron_left.svg',
                package: 'assets',
                width: 8,
                height: 14,
                colorFilter: const ColorFilter.mode(
                  Colors.black,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          left: 20,
          child: Center(
            child: Semantics(
              label: 'STEP ${tabController.index + 1} / 4',
              child: ExcludeSemantics(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < 3; i++) ...[
                            SvgPicture.asset(
                              'assets/design/onboarding_progress_${i < tabController.index
                                  ? 'complete'
                                  : i == tabController.index
                                  ? 'current'
                                  : 'pending'}.svg',
                              width: 74,
                              height: 11,
                            ),
                            const SizedBox(width: 6),
                          ],
                          SvgPicture.asset(
                            'assets/design/onboarding_progress_last_${tabController.index == 3 ? 'current' : 'pending'}.svg',
                            width: 11,
                            height: 11,
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < 4; i++) ...[
                            if (i > 0) const SizedBox(width: 38),
                            Text(
                              'STEP ${i + 1}',
                              textScaler: TextScaler.noScaling,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: i <= tabController.index
                                    ? const Color(0xFF4F69DF)
                                    : const Color(0xFF949494),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
