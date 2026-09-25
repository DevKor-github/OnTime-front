import 'package:on_time_front/presentation/recurring/recurrence_components.dart';
import 'package:on_time_front/presentation/recurring/recurrence_settings_sheet.dart';
import 'package:on_time_front/presentation/recurring/recurrence_labels.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/schedule_form_bloc.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
            Text(
              recurrenceText(context, '날짜와 시간', 'Date and time'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              recurrenceText(
                context,
                '약속이 언제 시작되는지, 반복할지 선택하세요.',
                'Choose when the appointment starts and whether it repeats.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              readOnly: true,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                filled: true,
                isDense: true,
                floatingLabelBehavior: FloatingLabelBehavior.always,
                contentPadding: const EdgeInsets.symmetric(vertical: 9),
                labelStyle: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF545454),
                ),
                floatingLabelStyle: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF545454),
                ),
                fillColor: Theme.of(context).colorScheme.surfaceContainerLowest,
                border: UnderlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.circular(8),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 17),
                  child: SvgPicture.asset(
                    'recurrence_date_time_calendar.svg',
                    package: 'assets',
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 55),
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: SvgPicture.asset(
                    'recurrence_date_time_chevron.svg',
                    package: 'assets',
                  ),
                ),
                suffixIconConstraints: const BoxConstraints(minWidth: 30),
                labelText: recurrenceText(context, '날짜', 'Date'),
                hintText: _localizedDateString(context, DateTime.now()),
                hintStyle: fadedHintStyle,
              ),
              controller: TextEditingController(
                text: state.scheduleDate.value == null
                    ? null
                    : _localizedDateString(context, state.scheduleDate.value!),
              ),
              onTap: () {
                context.showCupertinoDatePickerModal(
                  title: AppLocalizations.of(context)!.enterDate,
                  mode: CupertinoDatePickerMode.date,
                  initialValue: state.scheduleDate.value ?? DateTime.now(),
                  onDisposed: () {
                    context
                        .read<ScheduleDateTimeCubit>()
                        .validateCurrentSelection();
                  },
                  onSaved: (DateTime newDateTime) {
                    context.read<ScheduleDateTimeCubit>().scheduleDateChanged(
                      newDateTime,
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 8),
            TextField(
              readOnly: true,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                filled: true,
                isDense: true,
                floatingLabelBehavior: FloatingLabelBehavior.always,
                contentPadding: const EdgeInsets.symmetric(vertical: 9),
                labelStyle: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF545454),
                ),
                floatingLabelStyle: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF545454),
                ),
                fillColor: Theme.of(context).colorScheme.surfaceContainerLowest,
                border: UnderlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.circular(8),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 17),
                  child: SvgPicture.asset(
                    'recurrence_date_time_clock.svg',
                    package: 'assets',
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 55),
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: SvgPicture.asset(
                    'recurrence_date_time_chevron.svg',
                    package: 'assets',
                  ),
                ),
                suffixIconConstraints: const BoxConstraints(minWidth: 30),
                labelText: recurrenceText(context, '시간', 'Time'),
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
                  initialValue: state.scheduleTime.value ?? DateTime.now(),
                  onDisposed: () {
                    context
                        .read<ScheduleDateTimeCubit>()
                        .validateCurrentSelection();
                  },
                  onSaved: (DateTime newDateTime) {
                    context.read<ScheduleDateTimeCubit>().scheduleTimeChanged(
                      newDateTime,
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 24),
            if (form.originalSchedule == null || form.recurrenceRule != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recurrenceText(context, '반복 설정', 'Repeat'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 9),
                  RecurrenceValue(
                    compact: true,
                    label: recurrenceText(context, '반복 설정', 'Repeat'),
                    asset: 'recurrence_date_time_repeat.svg',
                    value: form.recurrenceRule == null
                        ? recurrenceText(context, '반복 안 함', 'Does not repeat')
                        : recurrencePatternLabel(context, form.recurrenceRule!),
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
                                    height:
                                        MediaQuery.sizeOf(context).height * .94,
                                    child: RecurrenceSettingsSheet(
                                      start: state.selectedScheduleDateTime!,
                                      timeZoneId: form.timeZoneId,
                                      initial: form.recurrenceRule,
                                      allowNone: form.originalSchedule == null,
                                      leadTime:
                                          form.totalPreparationTime +
                                          (form.moveTime ?? Duration.zero) +
                                          (form.scheduleSpareTime ??
                                              Duration.zero),
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
                ],
              ),
            if (state.isRecurring && form.recurrenceRule != null) ...[
              const SizedBox(height: 16),
              RecurrencePanel(
                highlighted: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recurrenceText(context, '반복 요약', 'Recurrence summary'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${recurrencePatternLabel(context, form.recurrenceRule!)}, ${recurrenceEndLabel(context, form.recurrenceRule!)}',
                      style: const TextStyle(fontSize: 12, height: 1.8),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      recurrenceText(context, '첫 일정 날짜', 'First occurrence'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      recurrenceText(
                        context,
                        '실제 첫 일정은 준비시간을 반영해 저장 전에 확인합니다.',
                        'Review the first occurrence after setting preparation time.',
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
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
                    Column(
                      spacing: 8,
                      children: [
                        for (
                          var index = 0;
                          index < state.occurrenceOffsetOptions.length;
                          index++
                        )
                          RecurrenceChoice(
                            label: _occurrenceLabel(
                              context,
                              index,
                              state.occurrenceOffsetOptions[index],
                            ),
                            selected:
                                state.selectedOccurrenceOffsetSeconds ==
                                state.occurrenceOffsetOptions[index],
                            onTap: () => context
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
    return DateFormat('yyyy년 M월 d일 (E)', 'ko').format(date);
  } else {
    return DateFormat(
      'yyyy.MM.dd.',
      Localizations.localeOf(context).toString(),
    ).format(date);
  }
}
