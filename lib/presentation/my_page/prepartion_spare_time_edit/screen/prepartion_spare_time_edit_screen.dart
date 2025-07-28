import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/presentation/app/bloc/app_bloc.dart';
import 'package:on_time_front/presentation/my_page/prepartion_spare_time_edit/bloc/default_preparation_spare_time_form_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/bloc/preparation_form_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/components/top_bar.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/components/preparation_form_create_list.dart';

class PrepartionSpareTimeEditScreen extends StatefulWidget {
  const PrepartionSpareTimeEditScreen({super.key});

  @override
  State<PrepartionSpareTimeEditScreen> createState() =>
      PrepartionSpareTimeEditScreenState();
}

class PrepartionSpareTimeEditScreenState
    extends State<PrepartionSpareTimeEditScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocProvider<DefaultPreparationSpareTimeFormBloc>(
          create: (context) => getIt.get<DefaultPreparationSpareTimeFormBloc>(),
          child: Builder(
            builder: (context) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final spareTime = context
                        .read<AppBloc>()
                        .state
                        .user
                        .mapOrNull((user) => user.spareTime) ??
                    Duration.zero;
                context.read<DefaultPreparationSpareTimeFormBloc>().add(
                      FormEditRequested(spareTime: spareTime),
                    );
              });
              return BlocBuilder<DefaultPreparationSpareTimeFormBloc,
                  DefaultPreparationSpareTimeFormState>(
                builder: (context, state) {
                  if (state.status ==
                      DefaultPreparationSpareTimeStatus.loading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.status ==
                      DefaultPreparationSpareTimeStatus.success) {
                    return BlocProvider<PreparationFormBloc>(
                      create: (context) => getIt.get<PreparationFormBloc>()
                        ..add(PreparationFormEditRequested(
                            preparationEntity: state.preparation!)),
                      child: BlocBuilder<PreparationFormBloc,
                          PreparationFormState>(
                        builder: (context, state) {
                          return Column(
                            children: [
                              TopBar(
                                onNextPageButtonClicked: state.isValid
                                    ? () {
                                        context
                                            .pop(state.toPreparationEntity());
                                      }
                                    : null,
                                onPreviousPageButtonClicked: context.pop,
                                isNextButtonEnabled: state.isValid,
                              ),
                              Expanded(
                                child: PreparationFormCreateList(
                                  preparationNameState: state,
                                  onNameChanged: (
                                      {required int index,
                                      required String value}) {
                                    context.read<PreparationFormBloc>().add(
                                        PreparationFormPreparationStepNameChanged(
                                            index: index,
                                            preparationStepName: value));
                                  },
                                  onCreationRequested: () {
                                    context.read<PreparationFormBloc>().add(
                                        PreparationFormPreparationStepCreationRequested());
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
            },
          ),
        ),
      ),
    );
  }
}
