import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/presentation/app/bloc/app_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/schedule_form_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/cubit/schedule_form_spare_time_cubit.dart';
import 'package:on_time_front/presentation/shared/components/cupertino_picker_modal.dart';

class ScheduleSpareAndPreparingTimeForm extends StatefulWidget {
  const ScheduleSpareAndPreparingTimeForm({
    super.key,
  });

  @override
  State<ScheduleSpareAndPreparingTimeForm> createState() =>
      _ScheduleSpareAndPreparingTimeFormState();
}

class _ScheduleSpareAndPreparingTimeFormState
    extends State<ScheduleSpareAndPreparingTimeForm> {
  late DateTime date;
  late Duration spareTime;

  @override
  Widget build(BuildContext context) {
    final ScheduleFormBloc scheduleFormBloc = context.read<ScheduleFormBloc>();
    return BlocBuilder<ScheduleFormBloc, ScheduleFormState>(
        builder: (context, state) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: FormField<Duration>(
              initialValue: Duration.zero,
              builder: (field) => TextField(
                readOnly: true,
                decoration: InputDecoration(labelText: '준비 시간'),
                controller: TextEditingController(
                    text: state.totalPreparationTime.toString()),
                onTap: () async {
                  final PreparationEntity? updatedPreparation = await context
                      .push('/preparationEdit', extra: state.preparation);
                  if (updatedPreparation != null) {
                    scheduleFormBloc.add(ScheduleFormPreparationChanged(
                        preparation: updatedPreparation));
                  }
                },
              ),
              onSaved: (value) {},
            ),
          ),
          SizedBox(
            width: 16,
          ),
          BlocBuilder<ScheduleFormSpareTimeCubit, ScheduleFormSpareTimeState>(
              builder: (context, spareTimeState) {
            final Duration spareTime = spareTimeState.spareTime.value ??
                spareTimeState.spareTime.value ??
                context.select((AppBloc appBloc) =>
                    appBloc.state.user.mapOrNull((user) => user.spareTime))!;
            return Expanded(
              flex: 1,
              child: TextField(
                readOnly: true,
                decoration: InputDecoration(labelText: ''),
                controller: TextEditingController(
                    text:
                        '${spareTime.inHours}시간 ${spareTime.inMinutes.remainder(60)}분'),
                onTap: () {
                  context.showCupertinoMinutePickerModal(
                      title: '시간을 입력해주세요',
                      initialValue: spareTime,
                      onSaved: (value) {
                        context
                            .read<ScheduleFormSpareTimeCubit>()
                            .spareTimeChanged(value);
                      });
                },
              ),
            );
          }),
        ],
      );
    });
  }
}
