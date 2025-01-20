import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/onboarding/mutly_page_form.dart';
import 'package:on_time_front/presentation/schedule_create/screens/schedule_create_screen.dart';

class ScheduleNameForm extends StatefulWidget {
  const ScheduleNameForm(
      {super.key,
      required this.formKey,
      required this.initalValue,
      this.onSaved});

  final GlobalKey<FormState> formKey;
  final ScheduleFormData initalValue;
  final Function(ScheduleFormData)? onSaved;

  @override
  State<ScheduleNameForm> createState() => _ScheduleNameFormState();
}

class _ScheduleNameFormState extends State<ScheduleNameForm> {
  ScheduleFormData _scheduleFormData = ScheduleFormData();

  @override
  Widget build(BuildContext context) {
    return MultiPageFormField(
      key: widget.formKey,
      onSaved: () {
        widget.onSaved?.call(_scheduleFormData);
      },
      child: TextFormField(
        initialValue: widget.initalValue.scheduleName,
        decoration: InputDecoration(labelText: '약속 이름'),
        textInputAction: TextInputAction.done,
        onSaved: (newValue) {
          _scheduleFormData =
              _scheduleFormData.copyWith(scheduleName: newValue!);
        },
      ),
    );
  }
}
