import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/domain/entities/default_preferences.dart';
import 'package:on_time_front/presentation/my_page/preparation_spare_time_edit/bloc/default_preparation_spare_time_form_bloc.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/bloc/preparation_form_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/components/preparation_form_create_list.dart';
import 'package:on_time_front/presentation/shared/components/modal_wide_button.dart';
import 'package:on_time_front/presentation/shared/components/two_action_dialog.dart';

class PreparationSpareTimeEditScreen extends StatelessWidget {
  const PreparationSpareTimeEditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<DefaultPreparationSpareTimeFormBloc>(
          create: (context) {
            return getIt.get<DefaultPreparationSpareTimeFormBloc>()
              ..add(const FormEditRequested());
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
            final bloc = context.read<DefaultPreparationSpareTimeFormBloc>();
            if (state.status == DefaultPreparationSpareTimeStatus.submitted &&
                bloc.current &&
                (ModalRoute.of(context)?.isCurrent ?? false)) {
              Navigator.of(context).pop();
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
              previous.editorVersion != current.editorVersion,
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
          previous.editorVersion != current.editorVersion,
      builder: (context, state) {
        if (!state.hasEditableData) {
          if (state.status == DefaultPreparationSpareTimeStatus.error) {
            return _PreferencesNotice(state: state);
          }
          return const _PreparationSpareTimeEditLoading();
        }
        return LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: Column(
              children: [
                if (state.status == DefaultPreparationSpareTimeStatus.error ||
                    state.status ==
                        DefaultPreparationSpareTimeStatus.followUpPending)
                  _PreferencesNotice(state: state),
                if (state.status == DefaultPreparationSpareTimeStatus.loading ||
                    state.status ==
                        DefaultPreparationSpareTimeStatus.submitting)
                  const LinearProgressIndicator(),
                SizedBox(
                  height: constraints.maxHeight < 620
                      ? 620
                      : constraints.maxHeight,
                  child: AbsorbPointer(
                    absorbing: !state.canEdit,
                    child: _PreparationSpareTimeEditContent(
                      key: const ValueKey('preparation_spare_time_form'),
                      spareTime: state.spareTime!,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PreparationSpareTimeEditLoading extends StatelessWidget {
  const _PreparationSpareTimeEditLoading();

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
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 20,
          children: [
            IconButton(
              onPressed: spareTime.inMinutes >= 5
                  ? () => context
                        .read<DefaultPreparationSpareTimeFormBloc>()
                        .add(const SpareTimeDecreased())
                  : null,
              icon: const Icon(Icons.remove),
            ),
            Text(
              AppLocalizations.of(
                context,
              )!.defaultPreferencesMinutes(spareTime.inMinutes),
            ),
            IconButton(
              onPressed: spareTime.inMinutes <= 1435
                  ? () => context
                        .read<DefaultPreparationSpareTimeFormBloc>()
                        .add(const SpareTimeIncreased())
                  : null,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ],
    );
  }
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
                  '${AppLocalizations.of(context)!.totalTime}${AppLocalizations.of(context)!.defaultPreferencesMinutes(totalDuration.inMinutes)}',
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

class _PreferencesNotice extends StatelessWidget {
  const _PreferencesNotice({required this.state});
  final DefaultPreparationSpareTimeFormState state;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bloc = context.read<DefaultPreparationSpareTimeFormBloc>();
    final receipt = state.receipt;
    final String message;
    if (receipt != null) {
      message = receipt.authorityPending
          ? l10n.defaultPreferencesAuthorityPending
          : state.needsReload
          ? l10n.defaultPreferencesSavedStoreChanged
          : receipt.reloadPending && receipt.deliveryPending
          ? l10n.defaultPreferencesBothPending
          : receipt.reloadPending
          ? l10n.defaultPreferencesReloadPending
          : l10n.defaultPreferencesDeliveryPending;
    } else if (state.needsReload) {
      message = l10n.defaultPreferencesConflict;
    } else if (!state.hasEditableData) {
      message = l10n.defaultPreferencesLoadFailed;
    } else if (state.failure == DefaultPreferencesFailure.invalid) {
      message = l10n.defaultPreferencesInvalid;
    } else {
      message = l10n.defaultPreferencesSaveFailed;
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(message, key: const ValueKey('default_preferences_notice')),
          if (receipt != null && !state.needsReload)
            TextButton(
              onPressed: () => bloc.add(const FormFollowUpRetried()),
              child: Text(l10n.defaultPreferencesRetryFollowUp),
            )
          else if (receipt == null &&
              (state.needsReload || !state.hasEditableData))
            TextButton(
              onPressed: () async {
                final owner = bloc.formOwner;
                if (state.hasEditableData) {
                  final decision = await showTwoActionDialog(
                    context,
                    config: TwoActionDialogConfig(
                      title: l10n.defaultPreferencesDiscardTitle,
                      description: l10n.defaultPreferencesDiscardDescription,
                      primaryAction: DialogActionConfig(
                        label: l10n.defaultPreferencesLoadLatest,
                        variant: ModalWideButtonVariant.destructive,
                      ),
                      secondaryAction: DialogActionConfig(label: l10n.cancel),
                    ),
                  );
                  if (decision != DialogActionResult.primary) return;
                }
                if (context.mounted && bloc.ownsForm(owner)) {
                  bloc.add(const FormEditRequested());
                }
              },
              child: Text(l10n.defaultPreferencesLoadLatest),
            ),
        ],
      ),
    );
  }
}
