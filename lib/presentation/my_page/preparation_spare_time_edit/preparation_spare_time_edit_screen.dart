import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/presentation/app/bloc/auth/auth_bloc.dart';
import 'package:on_time_front/presentation/my_page/preparation_spare_time_edit/bloc/default_preparation_spare_time_form_bloc.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/bloc/preparation_form_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/components/preparation_form_create_list.dart';
import 'package:on_time_front/presentation/shared/components/modal_wide_button.dart';
import 'package:on_time_front/presentation/shared/components/time_stepper.dart';
import 'package:on_time_front/presentation/shared/components/two_action_dialog.dart';

class PreparationSpareTimeEditScreen extends StatelessWidget {
  const PreparationSpareTimeEditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<DefaultPreparationSpareTimeFormBloc>(
          create: (context) {
            final spareTime =
                context.read<AuthBloc>().state.user.spareTimeOrNull ??
                Duration.zero;
            return getIt.get<DefaultPreparationSpareTimeFormBloc>()
              ..add(FormEditRequested(spareTime: spareTime));
          },
        ),
        BlocProvider<PreparationFormBloc>(
          create: (context) => getIt.get<PreparationFormBloc>(),
        ),
      ],
      child: const _PreparationSpareTimeEditView(),
    );
  }
}

class _PreparationSpareTimeEditView extends StatelessWidget {
  const _PreparationSpareTimeEditView();

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<
          DefaultPreparationSpareTimeFormBloc,
          DefaultPreparationSpareTimeFormState
        >(
          listenWhen: (previous, current) => previous.status != current.status,
          listener: (context, state) {
            if (state.status == DefaultPreparationSpareTimeStatus.submitted) {
              Navigator.of(context).pop();
            } else if (state.status ==
                DefaultPreparationSpareTimeStatus.error) {
              final l10n = AppLocalizations.of(context)!;
              showTwoActionDialog(
                context,
                config: TwoActionDialogConfig(
                  title: state.errorMessage ?? l10n.error,
                  primaryAction: DialogActionConfig(
                    label: l10n.ok,
                    variant: ModalWideButtonVariant.destructive,
                  ),
                ),
              );
            }
          },
        ),
        BlocListener<
          DefaultPreparationSpareTimeFormBloc,
          DefaultPreparationSpareTimeFormState
        >(
          listenWhen: (previous, current) =>
              current.status == DefaultPreparationSpareTimeStatus.success &&
              current.preparation != null &&
              previous.preparation != current.preparation,
          listener: (context, state) {
            context.read<PreparationFormBloc>().add(
              PreparationFormEditRequested(
                preparationEntity: state.preparation!,
              ),
            );
          },
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          shadowColor: Colors.transparent,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_rounded,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            onPressed: () => context.pop(),
          ),
          title: Text(
            AppLocalizations.of(context)!.editDefaultPreparation,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          actions: [
            BlocBuilder<
              DefaultPreparationSpareTimeFormBloc,
              DefaultPreparationSpareTimeFormState
            >(
              buildWhen: (previous, current) =>
                  previous.status != current.status ||
                  previous.spareTime != current.spareTime,
              builder: (context, state2) {
                return BlocBuilder<PreparationFormBloc, PreparationFormState>(
                  buildWhen: (previous, current) =>
                      previous.isValid != current.isValid,
                  builder: (context, preparationState) {
                    return TextButton(
                      onPressed: state2.canSubmit && preparationState.isValid
                          ? () {
                              final currentPreparationState = context
                                  .read<PreparationFormBloc>()
                                  .state;
                              context
                                  .read<DefaultPreparationSpareTimeFormBloc>()
                                  .add(
                                    FormSubmitted(
                                      note: '',
                                      preparation: currentPreparationState
                                          .toPreparationEntity(),
                                    ),
                                  );
                            }
                          : null,
                      child: Text(AppLocalizations.of(context)!.ok),
                    );
                  },
                );
              },
            ),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(33),
            child: SizedBox(height: 33),
          ),
        ),
        body: const SafeArea(child: _PreparationSpareTimeEditBody()),
      ),
    );
  }
}

class _PreparationSpareTimeEditBody extends StatelessWidget {
  const _PreparationSpareTimeEditBody();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<
      DefaultPreparationSpareTimeFormBloc,
      DefaultPreparationSpareTimeFormState
    >(
      buildWhen: (previous, current) =>
          previous.status != current.status ||
          previous.spareTime != current.spareTime ||
          previous.preparation != current.preparation,
      builder: (context, state) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: state.hasEditableData
              ? _PreparationSpareTimeEditContent(
                  key: const ValueKey('preparation_spare_time_form'),
                  spareTime: state.spareTime!,
                )
              : const _PreparationSpareTimeEditLoading(
                  key: ValueKey('preparation_spare_time_loading'),
                ),
        );
      },
    );
  }
}

class _PreparationSpareTimeEditLoading extends StatelessWidget {
  const _PreparationSpareTimeEditLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _PreparationSpareTimeEditContent extends StatelessWidget {
  const _PreparationSpareTimeEditContent({super.key, required this.spareTime});

  final Duration spareTime;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: _SpareTimeSection(spareTime: spareTime),
          ),
          SizedBox(height: 42.0),
          Expanded(
            child: BlocBuilder<PreparationFormBloc, PreparationFormState>(
              builder: (context, state) {
                return _PreparationSection(preparationNameState: state);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SpareTimeSection extends StatelessWidget {
  const _SpareTimeSection({required this.spareTime});

  final Duration spareTime;

  @override
  Widget build(BuildContext context) {
    final textTheme = TextTheme.of(context);
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: Text(
            AppLocalizations.of(context)!.editSpareTime,
            textAlign: TextAlign.start,
            style: textTheme.titleMedium,
          ),
        ),
        SizedBox(height: 24.0),
        TimeStepper(
          onSpareTimeIncreased: () {
            context.read<DefaultPreparationSpareTimeFormBloc>().add(
              const SpareTimeIncreased(),
            );
          },
          onSpareTimeDecreased: () {
            context.read<DefaultPreparationSpareTimeFormBloc>().add(
              const SpareTimeDecreased(),
            );
          },
          lowerBound: Duration(minutes: 10),
          value: spareTime,
        ),
      ],
    );
  }
}

extension on DefaultPreparationSpareTimeFormState {
  bool get hasEditableData =>
      (status == DefaultPreparationSpareTimeStatus.success ||
          status == DefaultPreparationSpareTimeStatus.submitting ||
          status == DefaultPreparationSpareTimeStatus.error) &&
      spareTime != null &&
      preparation != null;

  bool get canSubmit =>
      (status == DefaultPreparationSpareTimeStatus.success ||
          status == DefaultPreparationSpareTimeStatus.error) &&
      spareTime != null &&
      preparation != null;
}

class _PreparationSection extends StatelessWidget {
  const _PreparationSection({required this.preparationNameState});

  final PreparationFormState preparationNameState;

  @override
  Widget build(BuildContext context) {
    final textTheme = TextTheme.of(context);
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: Text(
            AppLocalizations.of(context)!.editPreparationTime,
            textAlign: TextAlign.start,
            style: textTheme.titleMedium,
          ),
        ),
        SizedBox(height: 24.0),
        SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 15.0),
            child: Builder(
              builder: (context) {
                final totalDuration = preparationNameState
                    .visiblePreparationStepList
                    .fold(
                      Duration.zero,
                      (prev, step) => prev + step.preparationTime.value,
                    );
                return Text(
                  '${AppLocalizations.of(context)!.totalTime}${totalDuration.inMinutes}분',
                  textAlign: TextAlign.end,
                );
              },
            ),
          ),
        ),
        Expanded(
          child: PreparationFormCreateList(
            preparationNameState: preparationNameState,
            onNameChanged: ({required int index, required String value}) {
              context.read<PreparationFormBloc>().add(
                PreparationFormPreparationStepNameChanged(
                  index: index,
                  preparationStepName: value,
                ),
              );
            },
            onCreationRequested: () {
              context.read<PreparationFormBloc>().add(
                const PreparationFormPreparationStepCreationRequested(),
              );
            },
          ),
        ),
      ],
    );
  }
}
