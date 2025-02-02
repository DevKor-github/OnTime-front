import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/schedule_form/schedule_form_bloc.dart';

class ScheduleNameForm extends StatefulWidget {
  const ScheduleNameForm(
      {super.key,
      required this.formKey,
      required this.initalValue,
      required this.onScheduleNameSaved});

  final GlobalKey<FormState> formKey;
  final ScheduleFormState initalValue;
  final ValueChanged<String> onScheduleNameSaved;

  @override
  State<ScheduleNameForm> createState() => _ScheduleNameFormState();
}

class _ScheduleNameFormState extends State<ScheduleNameForm> {
  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: TextFormField(
        initialValue: widget.initalValue.scheduleName,
        decoration: InputDecoration(labelText: '약속 이름'),
        textInputAction: TextInputAction.done,
        onSaved: (newValue) {
          widget.onScheduleNameSaved(newValue!);
        },
      ),
    );
  }
}
