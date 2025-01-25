import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/presentation/onboarding/mutly_page_form.dart';
import 'package:on_time_front/presentation/schedule_create/screens/schedule_create_screen.dart';

class ScheduleSpareAndPreparingTimeForm extends StatefulWidget {
  const ScheduleSpareAndPreparingTimeForm(
      {super.key,
      required this.formKey,
      required this.initalValue,
      this.onSaved});

  final GlobalKey<FormState> formKey;
  final ScheduleFormData initalValue;
  final Function(ScheduleFormData)? onSaved;

  @override
  State<ScheduleSpareAndPreparingTimeForm> createState() =>
      _ScheduleSpareAndPreparingTimeFormState();
}

class _ScheduleSpareAndPreparingTimeFormState
    extends State<ScheduleSpareAndPreparingTimeForm> {
  ScheduleFormData _scheduleFormData = ScheduleFormData();
  late DateTime date;
  late Duration spareTime;

  @override
  Widget build(BuildContext context) {
    return MultiPageFormField(
        key: widget.formKey,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: FormField<Duration>(
                initialValue: Duration.zero,
                builder: (field) => TextField(
                  readOnly: true,
                  decoration: InputDecoration(labelText: '준비 시간'),
                  controller: TextEditingController(text: '1시간'),
                  onTap: () {
                    context.go('/preparationEdit');
                  },
                ),
                onSaved: (value) {},
              ),
            ),
            SizedBox(
              width: 16,
            ),
            Expanded(
              flex: 1,
              child: FormField<Duration>(
                initialValue: widget.initalValue.spareTime ?? Duration.zero,
                builder: (field) => TextField(
                  readOnly: true,
                  decoration: InputDecoration(labelText: ''),
                  controller: TextEditingController(
                      text:
                          '${field.value?.inHours ?? 0}시간 ${field.value?.inMinutes.remainder(60) ?? 0}분'),
                  onTap: () {
                    _showModalBottomSheet(
                      context: context,
                      builder: () {
                        return Center(
                          child: CupertinoTimerPicker(
                            mode: CupertinoTimerPickerMode.hm,
                            initialTimerDuration: field.value ?? Duration.zero,
                            onTimerDurationChanged: (Duration newDateTime) {
                              spareTime = newDateTime;
                            },
                          ),
                        );
                      },
                      onSave: () {
                        field.didChange(spareTime);
                      },
                    );
                  },
                ),
                onSaved: (value) {
                  _scheduleFormData = _scheduleFormData.copyWith(
                    spareTime: value,
                  );
                },
              ),
            ),
          ],
        ),
        onSaved: () {
          widget.onSaved?.call(_scheduleFormData);
        });
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
