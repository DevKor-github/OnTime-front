import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/onboarding/mutly_page_form.dart';
import 'package:on_time_front/presentation/schedule_create/screens/schedule_create_screen.dart';

class SchedulePlaceMovingTimeForm extends StatefulWidget {
  const SchedulePlaceMovingTimeForm(
      {super.key,
      required this.formKey,
      required this.initalValue,
      this.onSaved});

  final GlobalKey<FormState> formKey;
  final ScheduleFormData initalValue;
  final Function(ScheduleFormData)? onSaved;

  @override
  State<SchedulePlaceMovingTimeForm> createState() =>
      _SchedulePlaceMovingTimeFormState();
}

class _SchedulePlaceMovingTimeFormState
    extends State<SchedulePlaceMovingTimeForm> {
  final FocusNode _placeFocusNode = FocusNode();
  final FocusNode _timeFocusNode = FocusNode();
  ScheduleFormData _scheduleFormData = ScheduleFormData();

  @override
  void initState() {
    super.initState();
  }

  void _showModalBottomSheet(
      BuildContext context, FormFieldState<Duration> field) {
    showModalBottomSheet<void>(
      isDismissible: false,
      context: context,
      builder: (BuildContext context) {
        final textTheme = Theme.of(context).textTheme;
        Duration duration = field.value ?? Duration.zero;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 29.0, vertical: 28.0),
          child: SizedBox(
            height: 334,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('시간을 선택해주세요', style: textTheme.titleMedium),
                Expanded(
                  child: Center(
                    child: CupertinoTimerPicker(
                      mode: CupertinoTimerPickerMode.hm,
                      initialTimerDuration: duration,
                      onTimerDurationChanged: (Duration newDuration) {
                        duration = newDuration;
                      },
                    ),
                  ),
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
                          field.didChange(duration);
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

  @override
  Widget build(BuildContext context) {
    return MultiPageFormField(
      key: widget.formKey,
      onSaved: () {
        widget.onSaved?.call(_scheduleFormData);
      },
      child: Column(
        children: [
          TextFormField(
              decoration: InputDecoration(labelText: '약속 장소'),
              focusNode: _placeFocusNode,
              textInputAction: TextInputAction.next,
              onSaved: (newValue) {
                _scheduleFormData =
                    _scheduleFormData.copyWith(placeName: newValue!);
              }),
          Row(
            children: [
              FormField<Duration>(
                initialValue: widget.initalValue.moveTime,
                onSaved: (newValue) {
                  _scheduleFormData =
                      _scheduleFormData.copyWith(moveTime: newValue);
                },
                builder: (field) {
                  return Expanded(
                    child: TextField(
                      readOnly: true,
                      decoration: InputDecoration(labelText: '이동 소요 시간'),
                      focusNode: _timeFocusNode,
                      textInputAction: TextInputAction.done,
                      controller: TextEditingController(
                          text: field.value != null
                              ? '${field.value!.inHours}시간 ${field.value!.inMinutes % 60}분'
                              : ''),
                      onTap: () {
                        _showModalBottomSheet(context, field);
                      },
                    ),
                  );
                },
              ),
            ],
          )
        ],
      ),
    );
  }
}
