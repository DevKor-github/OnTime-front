import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/presentation/app/bloc/app_bloc.dart';
import 'package:on_time_front/presentation/my_page/preparation_spare_time_edit/bloc/default_preparation_spare_time_form_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/components/top_bar.dart';
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
      child: const Scaffold(
        body: SafeArea(
          child: _PreparationSpareTimeEditView(),
        ),
      ),
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
                return Column(
                  children: [
                    TopBar(
                      onNextPageButtonClicked: state2.isValid
                          ? () {
                              context
                                  .read<DefaultPreparationSpareTimeFormBloc>()
                                  .add(
                                    FormSubmitted(
                                      note: '',
                                      preparation: state2.toPreparationEntity(),
                                    ),
                                  );
                              context.pop();
                            }
                          : null,
                      onPreviousPageButtonClicked: context.pop,
                      isNextButtonEnabled: state2.isValid,
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
                      value: state.spareTime!,
                    ),
                    Expanded(
                      child: PreparationFormCreateList(
                        preparationNameState: state2,
                        onNameChanged: (
                            {required int index, required String value}) {
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
              },
            ),
          );
        }

        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}
