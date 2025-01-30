import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/schedule_form/schedule_form_bloc.dart';

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
  late DateTime date;
  late DateTime time;

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
                  _showModalBottomSheet(
                      context: context,
                      builder: () {
                        return Center(
                          child: CupertinoDatePicker(
                            mode: CupertinoDatePickerMode.date,
                            initialDateTime: field.value!,
                            onDateTimeChanged: (DateTime newDateTime) {
                              date = newDateTime;
                            },
                          ),
                        );
                      },
                      onSave: () {
                        field.didChange(date);
                      });
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
                  _showModalBottomSheet(
                    context: context,
                    builder: () {
                      return Center(
                        child: CupertinoDatePicker(
                          mode: CupertinoDatePickerMode.time,
                          initialDateTime: field.value ?? DateTime.now(),
                          onDateTimeChanged: (DateTime newDateTime) {
                            time = newDateTime;
                          },
                        ),
                      );
                    },
                    onSave: () {
                      field.didChange(time);
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

  void _showModalBottomSheet({
    required BuildContext context,
    required Widget Function() builder,
    required VoidCallback onSave,
  }) {
    showModalBottomSheet<void>(
      isDismissible: false,
      context: context,
      builder: (BuildContext context) {
        final textTheme = Theme.of(context).textTheme;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 29.0, vertical: 28.0),
          child: SizedBox(
            height: 334,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('시간을 선택해주세요', style: textTheme.titleMedium),
                Expanded(
                  child: builder(),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Expanded(
                      flex: 1,
                      child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: ButtonStyle(
                            backgroundColor: WidgetStatePropertyAll(
                                Color.fromARGB(255, 220, 227, 255)),
                            foregroundColor: WidgetStatePropertyAll(
                                Color.fromARGB(255, 92, 121, 251)),
                          ),
                          child: Text('취소')),
                    ),
                    SizedBox(width: 20.0),
                    Expanded(
                      flex: 1,
                      child: ElevatedButton(
                        onPressed: () {
                          onSave();
                          Navigator.pop(context);
                        },
                        child: Text('확인'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
