import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_name/cubit/schedule_name_cubit.dart';
import 'package:on_time_front/l10n/app_localizations.dart';

class ScheduleNameForm extends StatefulWidget {
  const ScheduleNameForm({
    super.key,
  });

  @override
  State<ScheduleNameForm> createState() => _ScheduleNameFormState();
}

class _ScheduleNameFormState extends State<ScheduleNameForm> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ScheduleNameCubit, ScheduleNameState>(
        builder: (context, state) {
      return TextFormField(
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context)!.appointmentName,
          hintText: AppLocalizations.of(context)!.appointmentNameHint,
        ),
        textInputAction: TextInputAction.done,
        initialValue: state.scheduleName.value,
        onChanged: (scheduleName) {
          context.read<ScheduleNameCubit>().scheduleNameChanged(scheduleName);
        },
      );
    });
  }
}
