import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_place_moving_time.dart/cubit/schedule_place_moving_time_cubit.dart';
import 'package:on_time_front/presentation/shared/components/cupertino_picker_modal.dart';

class SchedulePlaceMovingTimeForm extends StatefulWidget {
  const SchedulePlaceMovingTimeForm({super.key});

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
    return BlocBuilder<SchedulePlaceMovingTimeCubit,
        SchedulePlaceMovingTimeState>(builder: (context, state) {
      return Column(
        children: [
          TextFormField(
            decoration: InputDecoration(
                labelText: '약속 장소',
                floatingLabelBehavior: FloatingLabelBehavior.always),
            initialValue: state.placeName.value,
            focusNode: _placeFocusNode,
            textInputAction: TextInputAction.next,
            onSaved: (newValue) {
              context
                  .read<SchedulePlaceMovingTimeCubit>()
                  .placeNameChanged(newValue ?? state.placeName.value);
            },
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  readOnly: true,
                  decoration: InputDecoration(labelText: '이동 소요 시간'),
                  focusNode: _timeFocusNode,
                  textInputAction: TextInputAction.done,
                  controller: TextEditingController(
                      text:
                          '${state.moveTime.value.inHours}시간 ${state.moveTime.value.inMinutes % 60}분'),
                  onTap: () {
                    context.showCupertinoTimerPickerModal(
                        title: '시간을 선택해 주세요',
                        mode: CupertinoTimerPickerMode.hm,
                        initialValue: state.moveTime.value,
                        onSaved: (Duration newTime) {
                          context
                              .read<SchedulePlaceMovingTimeCubit>()
                              .moveTimeChanged(newTime);
                        },
                        onDisposed: () {});
                  },
                ),
              ),
            ],
          )
        ],
      );
    });
  }
}
