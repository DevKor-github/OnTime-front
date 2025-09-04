import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/presentation/app/bloc/auth/app_bloc.dart';
import 'package:on_time_front/presentation/my_page/preparation_spare_time_edit/bloc/default_preparation_spare_time_form_bloc.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/bloc/preparation_form_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/components/preparation_form_create_list.dart';
import 'package:on_time_front/presentation/shared/components/time_stepper.dart';

class PreparationSpareTimeEditScreen extends StatelessWidget {
  const PreparationSpareTimeEditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DefaultPreparationSpareTimeFormBloc>(
      create: (context) {
        final spareTime = context
                .read<AppBloc>()
                .state
                .user
                .mapOrNull((user) => user.spareTime) ??
            Duration.zero;
        return getIt.get<DefaultPreparationSpareTimeFormBloc>()
          ..add(FormEditRequested(spareTime: spareTime));
      },
      child: const _PreparationSpareTimeEditView(),
    );
  }
}

class _PreparationSpareTimeEditView extends StatelessWidget {
  const _PreparationSpareTimeEditView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DefaultPreparationSpareTimeFormBloc,
        DefaultPreparationSpareTimeFormState>(
      builder: (context, state) {
        if (state.status == DefaultPreparationSpareTimeStatus.success) {
          return BlocProvider<PreparationFormBloc>(
            create: (context) => getIt.get<PreparationFormBloc>()
              ..add(PreparationFormEditRequested(
                  preparationEntity: state.preparation!)),
            child: BlocBuilder<PreparationFormBloc, PreparationFormState>(
              builder: (context, state2) {
                return Scaffold(
                  appBar: AppBar(
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
                      TextButton(
                        onPressed: state2.isValid
                            ? () {
                                context
                                    .read<DefaultPreparationSpareTimeFormBloc>()
                                    .add(
                                      FormSubmitted(
                                        note: '',
                                        preparation:
                                            state2.toPreparationEntity(),
                                      ),
                                    );
                                context.pop();
                              }
                            : null,
                        child: Text(AppLocalizations.of(context)!.ok),
                      ),
                    ],
                    bottom: const PreferredSize(
                      preferredSize: Size.fromHeight(33),
                      child: SizedBox(height: 33),
                    ),
                  ),
                  body: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child:
                                _SpareTimeSection(spareTime: state.spareTime!),
                          ),
                          SizedBox(
                            height: 42.0,
                          ),
                          Expanded(
                            child: _PreparationSection(
                              preparationNameState: state2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        }

        return const Center(child: CircularProgressIndicator());
      },
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
        SizedBox(
          height: 24.0,
        ),
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
        SizedBox(
          height: 24.0,
        ),
        SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 15.0),
            child: Text(
              AppLocalizations.of(context)!.totalTime,
              textAlign: TextAlign.end,
            ),
          ),
        ),
        PreparationFormCreateList(
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
      ],
    );
  }
}
