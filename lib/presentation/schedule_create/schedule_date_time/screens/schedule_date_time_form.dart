import 'package:on_time_front/presentation/recurring/recurrence_components.dart';
import 'package:on_time_front/presentation/recurring/recurrence_settings_sheet.dart';
import 'package:on_time_front/presentation/recurring/recurrence_labels.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/schedule_form_bloc.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/core/time/civil_time_resolver.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_date_time/cubit/schedule_date_time_cubit.dart';
import 'package:on_time_front/presentation/shared/components/cupertino_picker_modal.dart';
import 'package:on_time_front/presentation/schedule_create/components/message_bubble.dart';

//TODO: Format DateTime string
//TODO: Extract Text Field widget
class ScheduleDateTimeForm extends StatelessWidget {
  const ScheduleDateTimeForm({super.key});

  @override
  Widget build(BuildContext context) {
    final hintStyle =
        Theme.of(context).inputDecorationTheme.hintStyle ??
        Theme.of(context).textTheme.bodyLarge;
    final fadedHintStyle = hintStyle?.copyWith(
      color: (hintStyle.color ?? Theme.of(context).hintColor).withValues(
        alpha: 0.45,
      ),
    );

    return BlocBuilder<ScheduleDateTimeCubit, ScheduleDateTimeState>(
      builder: (context, state) {
        final form = context
            .read<ScheduleDateTimeCubit>()
            .scheduleFormBloc
            .state;
        return ListView(
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
                      hintStyle: fadedHintStyle,
                    ),
                    controller: TextEditingController(
                      text: state.scheduleDate.value == null
                          ? null
                          : _localizedDateString(
                              context,
                              state.scheduleDate.value!,
                            ),
                    ),
                    onTap: () {
                      context.showCupertinoDatePickerModal(
                        title: AppLocalizations.of(context)!.enterDate,
                        mode: CupertinoDatePickerMode.date,
                        initialValue:
                            state.scheduleDate.value ?? DateTime.now(),
                        onDisposed: () {
                          context
                              .read<ScheduleDateTimeCubit>()
                              .validateCurrentSelection();
                        },
                        onSaved: (DateTime newDateTime) {
                          context
                              .read<ScheduleDateTimeCubit>()
                              .scheduleDateChanged(newDateTime);
                        },
                      );
                    },
                  ),
                ),
                SizedBox(width: 30),
                Expanded(
                  flex: 1,
                  child: TextField(
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: '',
                      hintText: DateFormat.jm(
                        Localizations.localeOf(context).toString(),
                      ).format(DateTime.now()),
                      hintStyle: fadedHintStyle,
                    ),
                    controller: TextEditingController(
                      text: state.scheduleTime.value == null
                          ? null
                          : DateFormat.jm(
                              Localizations.localeOf(context).toString(),
                            ).format(state.scheduleTime.value!),
                    ),
                    onTap: () {
                      context.showCupertinoDatePickerModal(
                        title: AppLocalizations.of(context)!.enterTime,
                        mode: CupertinoDatePickerMode.time,
                        initialValue:
                            state.scheduleTime.value ?? DateTime.now(),
                        onDisposed: () {
                          context
                              .read<ScheduleDateTimeCubit>()
                              .validateCurrentSelection();
                        },
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
            const SizedBox(height: 24),
            if (form.originalSchedule == null || form.recurrenceRule != null)
              RecurrenceValue(
                label: recurrenceText(context, '반복', 'Repeat'),
                value: form.recurrenceRule == null
                    ? recurrenceText(context, '반복 안 함', 'Does not repeat')
                    : recurrenceLabel(context, form.recurrenceRule!),
                onTap: state.selectedScheduleDateTime == null
                    ? null
                    : () async {
                        final bloc = context.read<ScheduleFormBloc>();
                        final cubit = context.read<ScheduleDateTimeCubit>();
                        final selected =
                            await showModalBottomSheet<
                              RecurrenceSettingsResult
                            >(
                              context: context,
                              isScrollControlled: true,
                              useSafeArea: true,
                              builder: (context) => SizedBox(
                                height: MediaQuery.sizeOf(context).height * .9,
                                child: RecurrenceSettingsSheet(
                                  start: state.selectedScheduleDateTime!,
                                  timeZoneId: form.timeZoneId,
                                  initial: form.recurrenceRule,
                                  allowNone: form.originalSchedule == null,
                                  leadTime:
                                      form.totalPreparationTime +
                                      (form.moveTime ?? Duration.zero) +
                                      (form.scheduleSpareTime ?? Duration.zero),
                                ),
                              ),
                            );
                        if (selected != null &&
                            !bloc.isClosed &&
                            !cubit.isClosed) {
                          bloc.add(
                            ScheduleFormRecurringChanged(
                              selected.rule,
                              countChanged:
                                  form.recurrenceCountChanged ||
                                  selected.countChanged,
                            ),
                          );
                          cubit.setRecurring(selected.rule != null);
                        }
                      },
              ),
            if (state.isRecurring)
              Text(
                recurrenceText(
                  context,
                  '시작일 이후 조건에 맞는 날짜부터 반복해요. 실제 첫 일정은 준비시간을 반영해 저장 전에 확인합니다.',
                  'Repeats from the first matching date. Review the actual first occurrence after setting preparation time.',
                ),
              ),
            if (!state.isRecurring && state.hasPreviousOverlapMessage)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 16.0),
                child: MessageBubble(
                  message: state.getPreviousOverlapMessage(context)!,
                  type: MessageBubbleType.warning,
                ),
              ),
            if (!state.isRecurring && state.hasPastScheduleTimeMessage)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 16.0),
                child: MessageBubble(
                  message: state.getPastScheduleTimeMessage(context)!,
                  type: MessageBubbleType.error,
                ),
              ),
            if (!state.isRecurring && state.isNonexistentCivilTime)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 16.0),
                child: MessageBubble(
                  message: _dstGapMessage(context),
                  type: MessageBubbleType.error,
                ),
              ),
            if (!state.isRecurring && state.hasAmbiguousCivilTime)
              Padding(
                padding: const EdgeInsets.only(top: 12.0, left: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _dstOverlapMessage(context),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (
                          var index = 0;
                          index < state.occurrenceOffsetOptions.length;
                          index++
                        )
                          ChoiceChip(
                            label: Text(
                              _occurrenceLabel(
                                context,
                                index,
                                state.occurrenceOffsetOptions[index],
                              ),
                            ),
                            selected:
                                state.selectedOccurrenceOffsetSeconds ==
                                state.occurrenceOffsetOptions[index],
                            onSelected: (_) => context
                                .read<ScheduleDateTimeCubit>()
                                .occurrenceOffsetSelected(
                                  state.occurrenceOffsetOptions[index],
                                ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            if (!state.isRecurring && state.isOverlapping)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 16.0),
                child: MessageBubble(
                  message: state.getOverlapMessage(context)!,
                  type: MessageBubbleType.error,
                ),
              ),
          ],
        );
      },
    );
  }
}

String _dstGapMessage(BuildContext context) {
  return Localizations.localeOf(context).languageCode == 'ko'
      ? '일광절약시간 변경으로 존재하지 않는 시각이에요. 다른 시간을 선택해주세요.'
      : 'This time does not exist because of a daylight-saving change. Choose another time.';
}

String _dstOverlapMessage(BuildContext context) {
  return Localizations.localeOf(context).languageCode == 'ko'
      ? '이 시각은 두 번 발생해요. 사용할 시각을 선택해주세요.'
      : 'This time occurs twice. Choose which occurrence to use.';
}

String _occurrenceLabel(BuildContext context, int index, int offsetSeconds) {
  final occurrence = Localizations.localeOf(context).languageCode == 'ko'
      ? (index == 0 ? '첫 번째' : '두 번째')
      : (index == 0 ? 'First' : 'Second');
  return '$occurrence (${CivilTimeResolver.formatUtcOffset(offsetSeconds)})';
}

String _localizedDateString(BuildContext context, DateTime date) {
  final locale = Localizations.localeOf(context).languageCode;
  if (locale == 'ko') {
    return DateFormat('yyyy년 MM월 dd일', 'ko').format(date);
  } else {
    return DateFormat(
      'yyyy.MM.dd.',
      Localizations.localeOf(context).toString(),
    ).format(date);
  }
}
