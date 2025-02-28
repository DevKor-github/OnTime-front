import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/schedule_form/schedule_form_bloc.dart';
import 'package:on_time_front/presentation/shared/components/cupertino_picker_modal.dart';

class ScheduleTimeForm extends StatefulWidget {
  const ScheduleTimeForm({
    super.key,
    required this.formKey,
    required this.initalValue,
    required this.onScheduleTimeSaved,
    required this.onScheduleDateSaved,
  });

  final GlobalKey<FormState> formKey;
  final ScheduleFormState initalValue;
  final ValueChanged<DateTime> onScheduleTimeSaved;
  final ValueChanged<DateTime> onScheduleDateSaved;

  @override
  State<ScheduleTimeForm> createState() => _ScheduleTimeFormState();
}

class _ScheduleTimeFormState extends State<ScheduleTimeForm> {
  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: FormField<DateTime>(
              initialValue: widget.initalValue.scheduleTime ?? DateTime.now(),
              builder: (field) => TextField(
                readOnly: true,
                decoration: InputDecoration(labelText: '약속 시간'),
                controller: TextEditingController(
                    text:
                        '${field.value!.year}년 ${field.value!.month}월 ${field.value!.day}일'),
                onTap: () {
                  context.showCupertinoDatePickerModal(
                    title: '날짜를 입력해주세요.',
                    mode: CupertinoDatePickerMode.date,
                    initialValue: field.value!,
                    onDisposed: () {},
                    onSaved: (DateTime newDateTime) {
                      field.didChange(newDateTime);
                    },
                  );
                },
              ),
              onSaved: (value) {
                widget.onScheduleDateSaved(value!);
              },
            ),
          ),
          SizedBox(
            width: 16,
          ),
          Expanded(
            flex: 1,
            child: FormField<DateTime>(
              initialValue: widget.initalValue.scheduleTime ?? DateTime.now(),
              builder: (field) => TextField(
                readOnly: true,
                decoration: InputDecoration(labelText: ''),
                controller: TextEditingController(
                    text:
                        '${field.value!.hour > 12 ? '오후' : '오전'} ${field.value!.hour % 12}:${field.value!.minute}'),
                onTap: () {
                  context.showCupertinoDatePickerModal(
                    title: '시간을 입력해주세요.',
                    mode: CupertinoDatePickerMode.time,
                    initialValue: field.value!,
                    onDisposed: () {},
                    onSaved: (DateTime newDateTime) {
                      field.didChange(newDateTime);
                    },
                  );
                },
              ),
              onSaved: (value) {
                widget.onScheduleTimeSaved(value!);
              },
            ),
          ),
        ],
      ),
    );
  }
}
