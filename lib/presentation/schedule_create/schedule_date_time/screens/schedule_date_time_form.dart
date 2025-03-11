import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_date_time/cubit/schedule_date_time_cubit.dart';
import 'package:on_time_front/presentation/shared/components/cupertino_picker_modal.dart';

//TODO: Format DateTime string
//TODO: Extract Text Field widget
class ScheduleDateTimeForm extends StatelessWidget {
  const ScheduleDateTimeForm({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ScheduleDateTimeCubit, ScheduleDateTimeState>(
        builder: (context, state) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              readOnly: true,
              decoration: InputDecoration(
                labelText: '약속 시간',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                hintText:
                    '${DateTime.now().year}년 ${DateTime.now().month}월 ${DateTime.now().day}일',
              ),
              controller: TextEditingController(
                  text: state.scheduleDate.value == null
                      ? null
                      : '${state.scheduleDate.value!.year}년 ${state.scheduleDate.value!.month}월 ${state.scheduleDate.value!.day}일'),
              onTap: () {
                context.showCupertinoDatePickerModal(
                  title: '날짜를 입력해주세요.',
                  mode: CupertinoDatePickerMode.date,
                  initialValue: state.scheduleDate.value ?? DateTime.now(),
                  onDisposed: () {},
                  onSaved: (DateTime newDateTime) {
                    context
                        .read<ScheduleDateTimeCubit>()
                        .scheduleDateChanged(newDateTime);
                  },
                );
              },
            ),
          ),
          SizedBox(
            width: 16,
          ),
          Expanded(
            flex: 1,
            child: TextField(
              readOnly: true,
              decoration: InputDecoration(
                  labelText: '',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  hintText:
                      '${DateTime.now().hour}시 ${DateTime.now().minute}분'),
              controller: TextEditingController(
                  text: state.scheduleTime.value == null
                      ? null
                      : '${state.scheduleTime.value!.hour > 12 ? '오후' : '오전'} ${state.scheduleTime.value!.hour % 12}:${state.scheduleTime.value!.minute}'),
              onTap: () {
                context.showCupertinoDatePickerModal(
                  title: '시간을 입력해주세요.',
                  mode: CupertinoDatePickerMode.time,
                  initialValue: state.scheduleTime.value ?? DateTime.now(),
                  onDisposed: () {},
                  onSaved: (DateTime newDateTime) {
                    context
                        .read<ScheduleDateTimeCubit>()
                        .scheduleTimeChanged(newDateTime);
                  },
                );
              },
            ),
          ),
        ],
      );
    });
  }
}
