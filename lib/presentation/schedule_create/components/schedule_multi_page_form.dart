import 'package:on_time_front/domain/entities/schedule_save.dart';
import 'package:on_time_front/presentation/recurring/recurrence_time_choice_sheet.dart';
import 'package:on_time_front/presentation/recurring/recurrence_components.dart';
import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';
import 'package:on_time_front/presentation/recurring/recurrence_labels.dart';
import 'package:on_time_front/presentation/recurring/recurrence_review_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/schedule_form_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/components/top_bar.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_date_time/cubit/schedule_date_time_cubit.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_date_time/screens/schedule_date_time_form.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_name/screens/schedule_name_form.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_name/cubit/schedule_name_cubit.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_place_moving_time/cubit/schedule_place_moving_time_cubit.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_place_moving_time/screens/schedule_place_moving_time_form.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/cubit/schedule_form_spare_time_cubit.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/screens/schedule_spare_and_preparing_time_form.dart';
import 'package:on_time_front/presentation/shared/components/step_progress.dart';
import 'package:on_time_front/l10n/app_localizations.dart';

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
    formKeys = List.generate(
      _tabController.length,
      (index) => GlobalKey<FormState>(),
    );
    super.initState();
  }

  @override
  void dispose() {
    _pageViewController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ScheduleFormBloc, ScheduleFormState>(
      listenWhen: (previous, current) =>
          previous.submissionStatus != current.submissionStatus,
      listener: (context, state) async {
        final bloc = context.read<ScheduleFormBloc>();
        final owner = bloc.formOwner;
        final mutation = state.mutationId;
        bool ownsCurrentForm() =>
            mounted &&
            context.mounted &&
            bloc.ownsForm(owner) &&
            bloc.state.mutationId == mutation &&
            (ModalRoute.of(context)?.isCurrent ?? false);
        if (!context.mounted || !ownsCurrentForm()) return;
        if (state.submissionStatus == ScheduleFormSubmissionStatus.review) {
          final selected = await showModalBottomSheet<Set<String>>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (context) => SizedBox(
              height: MediaQuery.sizeOf(context).height * .94,
              child: RecurrenceReviewSheet(
                review: state.recurrenceReview!,
                form: state,
              ),
            ),
          );
          if (!context.mounted || !ownsCurrentForm()) return;
          if (selected == null) {
            bloc.add(const ScheduleFormReviewDismissed());
          } else if (state.originalSchedule == null) {
            bloc.add(
              ScheduleFormCreated(confirmed: true, excludedSlots: selected),
            );
          } else {
            bloc.add(
              ScheduleFormUpdated(confirmed: true, excludedSlots: selected),
            );
          }
        } else if (state.submissionStatus ==
            ScheduleFormSubmissionStatus.timeChoice) {
          final choice = await showModalBottomSheet<RepeatedCivilTime>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (context) => SizedBox(
              height: MediaQuery.sizeOf(context).height * .94,
              child: RecurrenceTimeChoiceSheet(
                date: state.repeatedTimeDate!,
                timeZoneId: state.timeZoneId,
              ),
            ),
          );
          if (!context.mounted || !ownsCurrentForm()) return;
          if (choice == null) {
            bloc.add(const ScheduleFormReviewDismissed());
          } else {
            bloc.add(ScheduleFormRepeatedTimeChosen(choice));
          }
        } else if (state.submissionStatus ==
            ScheduleFormSubmissionStatus.success) {
          Navigator.of(context).pop(true);
        } else if (state.submissionStatus ==
            ScheduleFormSubmissionStatus.deliveryPending) {
          final l = AppLocalizations.of(context)!;
          final retry = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(l.scheduleSavedPending),
              content: Text(l.scheduleDeliveryPendingBody),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l.ok),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(l.dataRetry),
                ),
              ],
            ),
          );
          if (!context.mounted || !ownsCurrentForm()) return;
          if (retry == true) {
            widget.onSaved?.call();
          } else {
            Navigator.of(context).pop(true);
          }
        } else if (state.submissionStatus ==
            ScheduleFormSubmissionStatus.failure) {
          if (state.saveFailure == ScheduleSaveFailure.conflict) {
            final l = AppLocalizations.of(context)!;
            final review = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(l.scheduleSaveConflict),
                content: Text(l.scheduleSaveConflictBody),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(l.cancel),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(l.scheduleReviewCurrent),
                  ),
                ],
              ),
            );
            if (!context.mounted || !ownsCurrentForm() || review != true) {
              return;
            }
            try {
              final current = await context
                  .read<ScheduleFormBloc>()
                  .reviewCurrent();
              if (!context.mounted || !ownsCurrentForm()) return;
              final accept = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(l.scheduleReviewCurrent),
                  content: SingleChildScrollView(
                    child: Text(
                      current.current == null
                          ? l.scheduleCreateReview
                          : '${current.current!.schedule.scheduleName}\n${current.current!.schedule.place.placeName}\n${current.current!.schedule.scheduleTime}\n${current.current!.preparation.ordered.preparationStepList.map((s) => '${s.preparationName}: ${s.preparationTime.inMinutes}').join('\n')}\n\n${l.scheduleDraftPreserved}',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(l.cancel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(l.ok),
                    ),
                  ],
                ),
              );
              if (context.mounted && ownsCurrentForm() && accept == true) {
                context.read<ScheduleFormBloc>().acceptReviewedBaseline(
                  current.owner,
                  current.baseline,
                  current.current?.schedule,
                );
              }
            } catch (_) {
              if (context.mounted && ownsCurrentForm()) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l.scheduleSaveUnavailable)),
                );
              }
            }
            return;
          }

          final retry = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (context) => SizedBox(
              height: MediaQuery.sizeOf(context).height * .94,
              child: RecurrenceSaveErrorSheet(
                message: state.saveFailure == null
                    ? state.submissionError ??
                          AppLocalizations.of(context)!.error
                    : state.saveFailure == ScheduleSaveFailure.protected
                    ? AppLocalizations.of(context)!.scheduleSaveProtected
                    : AppLocalizations.of(context)!.scheduleSaveUnavailable,
              ),
            ),
          );
          if (ownsCurrentForm() && retry == true) widget.onSaved?.call();
        }
      },
      child: BlocBuilder<ScheduleFormBloc, ScheduleFormState>(
        builder: (context, state) {
          if (state.status == ScheduleFormStatus.error) {
            return Text(AppLocalizations.of(context)!.error);
          } else if (state.status == ScheduleFormStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          final isSubmitting =
              state.submissionStatus == ScheduleFormSubmissionStatus.submitting;

          return MultiBlocProvider(
            providers: [
              BlocProvider<ScheduleNameCubit>(
                create: (context) => ScheduleNameCubit(
                  scheduleFormBloc: context.read<ScheduleFormBloc>(),
                ),
              ),
              BlocProvider(
                create: (context) => getIt.get<ScheduleDateTimeCubit>(
                  param1: context.read<ScheduleFormBloc>(),
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
            child: Builder(
              builder: (context) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  child: Column(
                    children: [
                      TopBar(
                        showAction: false,
                        actionLabel: _tabController.index == 3
                            ? recurrenceText(
                                context,
                                state.recurrenceRule == null ? '저장' : '검토하기',
                                state.recurrenceRule == null
                                    ? 'Save'
                                    : 'Review',
                              )
                            : null,
                        onNextPageButtonClicked:
                            (state.isValid && !isSubmitting)
                            ? () => _onNextPageButtonClicked(context)
                            : null,
                        // 버튼 활성화 판별
                        isNextButtonEnabled: state.isValid && !isSubmitting,
                        onPreviousPageButtonClicked: isSubmitting
                            ? null
                            : _onPreviousPageButtonClicked,
                      ),
                      SizedBox(height: 26),
                      StepProgress(
                        currentStep: _tabController.index,
                        totalSteps: _tabController.length,
                        singleLine: true,
                        labels: [
                          recurrenceText(context, '기본 정보', 'Details'),
                          recurrenceText(context, '날짜와 시간', 'Date & time'),
                          recurrenceText(context, '장소와 이동', 'Travel'),
                          recurrenceText(context, '준비 과정', 'Preparation'),
                        ],
                      ),
                      SizedBox(height: 24),
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
                        ),
                      ),
                      const SizedBox(height: 12),
                      ScreenActions(
                        action: _tabController.index == 3
                            ? recurrenceText(
                                context,
                                state.recurrenceRule == null ? '저장' : '검토하기',
                                state.recurrenceRule == null
                                    ? 'Save'
                                    : 'Review',
                              )
                            : AppLocalizations.of(context)!.next,
                        onAction: state.isValid && !isSubmitting
                            ? () => _onNextPageButtonClicked(context)
                            : null,
                        onBack: isSubmitting
                            ? null
                            : _onPreviousPageButtonClicked,
                        loading: isSubmitting,
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _onNextPageButtonClicked(BuildContext context) {
    // Revalidate the current step before proceeding

    switch (_pageCubitTypes[_tabController.index]) {
      case const (ScheduleNameCubit):
        context.read<ScheduleNameCubit>().scheduleNameSubmitted();
        // Initialize next cubit after submitting current page
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.read<ScheduleDateTimeCubit>().initialize();
        });
        break;
      case const (ScheduleDateTimeCubit):
        final didSubmit = context
            .read<ScheduleDateTimeCubit>()
            .scheduleDateTimeSubmitted();
        if (!didSubmit) {
          return;
        }
        // Initialize next cubit after submitting current page
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.read<SchedulePlaceMovingTimeCubit>().initialize();
        });
        break;
      case const (SchedulePlaceMovingTimeCubit):
        context
            .read<SchedulePlaceMovingTimeCubit>()
            .schedulePlaceMovingTimeSubmitted();
        // Initialize next cubit after submitting current page
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.read<ScheduleFormSpareTimeCubit>().initialize();
        });
        break;
      case const (ScheduleFormSpareTimeCubit):
        context.read<ScheduleFormSpareTimeCubit>().scheduleSpareTimeSubmitted();
        break;
    }
    if (_tabController.index < _tabController.length - 1) {
      _updateCurrentPageIndex(_tabController.index + 1);
      _reinitializeCurrentStep(context);
    } else {
      widget.onSaved?.call();
    }
  }

  void _onPreviousPageButtonClicked() {
    // Set validity to true when going to previous page
    context.read<ScheduleFormBloc>().add(ScheduleFormValidated(isValid: true));

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
    _unfocusCurrentInput();
    _tabController.index = index;
    _pageViewController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _unfocusCurrentInput() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _reinitializeCurrentStep(BuildContext context) {
    switch (_pageCubitTypes[_tabController.index]) {
      case const (ScheduleNameCubit):
        context.read<ScheduleNameCubit>().initialize();
        break;
      case const (ScheduleDateTimeCubit):
        context.read<ScheduleDateTimeCubit>().initialize();
        break;
      case const (SchedulePlaceMovingTimeCubit):
        context.read<SchedulePlaceMovingTimeCubit>().initialize();
        break;
      case const (ScheduleFormSpareTimeCubit):
        context.read<ScheduleFormSpareTimeCubit>().initialize();
        break;
    }
  }
}
