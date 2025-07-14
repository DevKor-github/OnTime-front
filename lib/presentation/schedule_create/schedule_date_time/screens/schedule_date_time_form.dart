import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
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
                labelText: AppLocalizations.of(context)!.appointmentTime,
                hintText:
                    DateFormat.yMd(Localizations.localeOf(context).toString())
                        .format(DateTime.now()),
              ),
              controller: TextEditingController(
                  text: state.scheduleDate.value == null
                      ? null
                      : DateFormat.yMd(
                              Localizations.localeOf(context).toString())
                          .format(state.scheduleDate.value!)),
              onTap: () {
                context.showCupertinoDatePickerModal(
                  title: AppLocalizations.of(context)!.enterDate,
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
            width: 30,
          ),
          Expanded(
            flex: 1,
            child: TextField(
              readOnly: true,
              decoration: InputDecoration(
                  labelText: '',
                  hintText:
                      DateFormat.jm(Localizations.localeOf(context).toString())
                          .format(DateTime.now())),
              controller: TextEditingController(
                text: state.scheduleTime.value == null
                    ? null
                    : DateFormat.jm(Localizations.localeOf(context).toString())
                        .format(state.scheduleTime.value!),
              ),
              onTap: () {
                context.showCupertinoDatePickerModal(
                  title: AppLocalizations.of(context)!.enterTime,
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
