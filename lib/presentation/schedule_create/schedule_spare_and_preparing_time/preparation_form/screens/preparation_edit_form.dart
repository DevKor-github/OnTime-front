import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/bloc/preparation_form_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/components/top_bar.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/components/preparation_form_create_list.dart';

class PreparationEditForm extends StatefulWidget {
  const PreparationEditForm({super.key, required this.preparationEntity});

  final PreparationEntity preparationEntity;

  @override
  State<PreparationEditForm> createState() => _PreparationEditFormState();
}

class _PreparationEditFormState extends State<PreparationEditForm> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocProvider<PreparationFormBloc>(
          create: (context) => getIt.get<PreparationFormBloc>()
            ..add(PreparationFormEditRequested(
                preparationEntity: widget.preparationEntity)),
          child: BlocBuilder<PreparationFormBloc, PreparationFormState>(
            builder: (context, state) {
              return Column(
                children: [
                  TopBar(
                    onNextPageButtonClicked: state.isValid
                        ? () {
                            context.pop(state.toPreparationEntity());
                          }
                        : null,
                    onPreviousPageButtonClicked: context.pop,
                  ),
                  Expanded(
                    child: PreparationFormCreateList(
                      preparationNameState: state,
                      onNameChanged: (
                          {required int index, required String value}) {
                        context.read<PreparationFormBloc>().add(
                            PreparationFormPreparationStepNameChanged(
                                index: index, preparationStepName: value));
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
        ),
      ),
    );
  }
}
