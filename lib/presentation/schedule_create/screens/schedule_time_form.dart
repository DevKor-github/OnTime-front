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
                    context: context,
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
                    context: context,
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
