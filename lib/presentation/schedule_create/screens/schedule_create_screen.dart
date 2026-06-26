import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/presentation/app/bloc/auth/auth_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/schedule_form_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/components/keyboard_backed_bottom_sheet.dart';
import 'package:on_time_front/presentation/schedule_create/components/schedule_multi_page_form.dart';

class ScheduleCreateScreen extends StatelessWidget {
  const ScheduleCreateScreen({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  Widget build(BuildContext context) {
    return KeyboardBackedBottomSheet(
      child: BlocProvider<ScheduleFormBloc>(
        create: (context) =>
            getIt.get<ScheduleFormBloc>(param1: context.read<AuthBloc>())
              ..add(ScheduleFormCreateRequested(initialDate: initialDate)),
        child: BlocBuilder<ScheduleFormBloc, ScheduleFormState>(
          builder: (context, state) {
            return ScheduleMultiPageForm(
              onSaved: () => context.read<ScheduleFormBloc>().add(
                const ScheduleFormCreated(),
              ),
            );
          },
        ),
      ),
    );
  }
}
