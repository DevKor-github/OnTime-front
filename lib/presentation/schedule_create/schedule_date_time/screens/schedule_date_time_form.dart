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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.appointmentTime,
                    hintText: _localizedDateString(context, DateTime.now()),
                  ),
                  controller: TextEditingController(
                      text: state.scheduleDate.value == null
                          ? null
                          : _localizedDateString(
                              context, state.scheduleDate.value!)),
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
                      hintText: DateFormat.jm(
                              Localizations.localeOf(context).toString())
                          .format(DateTime.now())),
                  controller: TextEditingController(
                    text: state.scheduleTime.value == null
                        ? null
                        : DateFormat.jm(
                                Localizations.localeOf(context).toString())
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
          ),
          if (state.hasOverlapMessage)
            Padding(
              padding: const EdgeInsets.only(top: 8.0, left: 16.0),
              child: state.isOverlapError
                  ? _ErrorMessageBubble(
                      message: state.getOverlapMessage(context)!,
                    )
                  : _WarningMessageBubble(
                      message: state.getOverlapMessage(context)!,
                    ),
            ),
        ],
      );
    });
  }
}

String _localizedDateString(BuildContext context, DateTime date) {
  final locale = Localizations.localeOf(context).languageCode;
  if (locale == 'ko') {
    return DateFormat('yyyy년 MM월 dd일', 'ko').format(date);
  } else {
    return DateFormat('yyyy.mm.dd.', Localizations.localeOf(context).toString())
        .format(date);
  }
}

class _WarningMessageBubble extends StatelessWidget {
  const _WarningMessageBubble({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: colorScheme.primaryContainer,
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 20,
            color: colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorMessageBubble extends StatelessWidget {
  const _ErrorMessageBubble({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: colorScheme.errorContainer,
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 20,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
