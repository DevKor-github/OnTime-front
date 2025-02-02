import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/schedule_form/schedule_form_bloc.dart';
import 'package:on_time_front/presentation/shared/components/cupertino_picker_modal.dart';

class SchedulePlaceMovingTimeForm extends StatefulWidget {
  const SchedulePlaceMovingTimeForm(
      {super.key,
      required this.formKey,
      required this.initalValue,
      required this.onPlaceNameSaved,
      required this.onMovingTimeSaved});

  final GlobalKey<FormState> formKey;
  final ScheduleFormState initalValue;
  final ValueChanged<String> onPlaceNameSaved;
  final ValueChanged<Duration> onMovingTimeSaved;

  @override
  State<SchedulePlaceMovingTimeForm> createState() =>
      _SchedulePlaceMovingTimeFormState();
}

class _SchedulePlaceMovingTimeFormState
    extends State<SchedulePlaceMovingTimeForm> {
  final FocusNode _placeFocusNode = FocusNode();
  final FocusNode _timeFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _placeFocusNode.dispose();
    _timeFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: Column(
        children: [
          TextFormField(
              decoration: InputDecoration(labelText: '약속 장소'),
              focusNode: _placeFocusNode,
              textInputAction: TextInputAction.next,
              onSaved: (newValue) {
                widget.onPlaceNameSaved(newValue!);
              }),
          Row(
            children: [
              FormField<Duration>(
                initialValue: widget.initalValue.moveTime,
                onSaved: (newValue) {
                  widget.onMovingTimeSaved(newValue!);
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
                        context.showCupertinoTimerPickerModal(
                            title: '시간을 선택해 주세요',
                            mode: CupertinoTimerPickerMode.hm,
                            context: context,
                            initialValue: field.value ?? Duration.zero,
                            onSaved: (Duration newTime) {
                              field.didChange(newTime);
                            },
                            onDisposed: () {});
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
