import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/schedule_form/schedule_form_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/compoenent/schedule_multi_page_form.dart';

class ScheduleEditScreen extends StatelessWidget {
  const ScheduleEditScreen({super.key, required this.scheduleId});

  final String scheduleId;

  @override
  Widget build(BuildContext context) {
    return Material(
      child: SafeArea(
        child: BlocProvider<ScheduleFormBloc>(
          create: (context) => getIt.get<ScheduleFormBloc>()
            ..add(ScheduleFormEditRequested(scheduleId: scheduleId)),
          child: BlocBuilder<ScheduleFormBloc, ScheduleFormState>(
            builder: (context, state) {
              return ScheduleMultiPageForm(
                  onSaved: () => context.read<ScheduleFormBloc>().add(
                        const ScheduleFormUpdated(),
                      ));
            },
          ),
        ),
      ),
    );
  }
}
