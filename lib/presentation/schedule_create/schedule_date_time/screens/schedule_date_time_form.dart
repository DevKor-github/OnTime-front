import 'package:on_time_front/core/time/time_zone_rules.dart';
import 'package:on_time_front/domain/entities/civil_date_time.dart';
import 'package:on_time_front/domain/entities/schedule_time_resolution.dart';
import 'package:on_time_front/presentation/shared/time/schedule_zoned_time.dart';
import 'package:on_time_front/presentation/recurring/recurrence_components.dart';
import 'package:on_time_front/presentation/recurring/recurrence_settings_sheet.dart';
import 'package:on_time_front/presentation/recurring/recurrence_labels.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/schedule_form_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/core/time/civil_time_resolver.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_date_time/cubit/schedule_date_time_cubit.dart';
import 'package:on_time_front/presentation/shared/components/civil_date_time_picker.dart';
import 'schedule_time_zone_picker.dart';
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
              decoration: InputDecoration(
                filled: true,
                labelStyle: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF545454),
                ),
                floatingLabelStyle: const TextStyle(
                  fontSize: 12,
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
                prefixIcon: const Icon(Icons.calendar_today_outlined, size: 24),
                suffixIcon: const Icon(Icons.chevron_right, size: 20),
                labelText: AppLocalizations.of(context)!.appointmentTime,
                hintText: _localizedDateString(context, DateTime.now()),
                hintStyle: fadedHintStyle,
              ),
              controller: TextEditingController(
                text: state.scheduleDate.value == null
                    ? null
                    : _localizedDateString(context, state.scheduleDate.value!),
              ),
              onTap: () async {
                final cubit = context.read<ScheduleDateTimeCubit>();
                final owns = _captureFormOwner(context, cubit);
                final value = await showCivilDateTimePicker(
                  context: context,
                  title: AppLocalizations.of(context)!.enterDate,
                  dateOnly: true,
                  initialCivil:
                      state.selectedScheduleDateTime ??
                      state.scheduleDate.value ??
                      DateTime.now(),
                );
                if (!owns()) return;
                if (value != null) await cubit.scheduleDateChanged(value);
                if (owns()) cubit.validateCurrentSelection();
              },
            ),
            const SizedBox(height: 8),
            TextField(
              readOnly: true,
              decoration: InputDecoration(
                filled: true,
                labelStyle: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF545454),
                ),
                floatingLabelStyle: const TextStyle(
                  fontSize: 12,
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
                prefixIcon: const Icon(Icons.schedule, size: 24),
                suffixIcon: const Icon(Icons.chevron_right, size: 20),
                labelText: recurrenceText(context, '시간', 'Time'),
                hintText: TimeOfDay.now().format(context),
                hintStyle: fadedHintStyle,
              ),
              controller: TextEditingController(
                text: state.scheduleTime.value == null
                    ? null
                    : TimeOfDay.fromDateTime(
                        state.scheduleTime.value!,
                      ).format(context),
              ),
              onTap: () async {
                final cubit = context.read<ScheduleDateTimeCubit>();
                final owns = _captureFormOwner(context, cubit);
                final value = await showCivilDateTimePicker(
                  context: context,
                  title: AppLocalizations.of(context)!.enterTime,
                  dateOnly: false,
                  initialCivil:
                      state.selectedScheduleDateTime ??
                      state.scheduleTime.value ??
                      DateTime.now(),
                );
                if (!owns()) return;
                if (value != null) await cubit.scheduleTimeChanged(value);
                if (owns()) cubit.validateCurrentSelection();
              },
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.public),
              title: Text(
                state.timeZoneId.isEmpty
                    ? AppLocalizations.of(context)!.zonedTimeChooseZone
                    : state.timeZoneId,
              ),
              subtitle: Text(
                state.timeZoneExplicitlySelected
                    ? AppLocalizations.of(context)!.zonedTimeSelectedZone
                    : form.originalSchedule != null
                    ? AppLocalizations.of(context)!.zonedTimeSavedZone
                    : state.timeZoneId.isEmpty
                    ? AppLocalizations.of(
                        context,
                      )!.zonedTimeSelectUnavailableZone
                    : AppLocalizations.of(context)!.zonedTimeDetectedZone,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final cubit = context.read<ScheduleDateTimeCubit>();
                final owns = _captureFormOwner(context, cubit);
                final zone = await showScheduleTimeZonePicker(
                  context: context,
                  currentZone: state.timeZoneId,
                  civil: state.selectedScheduleDateTime,
                  offsetSeconds: state.selectedOccurrenceOffsetSeconds,
                  isCurrent: owns,
                );
                if (zone != null && owns()) {
                  await cubit.timeZoneSelected(zone);
                }
              },
            ),
            if (state.selectedScheduleDateTime != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ScheduleZonedTime(
                  civil: CivilDateTime.fromFields(
                    state.selectedScheduleDateTime!,
                  ),
                  timeZoneId: state.timeZoneId,
                  resolution: _selectionResolution(state),
                  showResolutionStatus:
                      state.isRecurring ||
                      !(state.isNonexistentCivilTime ||
                          state.hasAmbiguousCivilTime ||
                          state.requiresOccurrenceChoice),
                ),
              ),
            const SizedBox(height: 24),
            if (form.originalSchedule == null || form.recurrenceRule != null)
              RecurrenceValue(
                label: recurrenceText(context, '반복 설정', 'Repeat'),
                icon: Icons.repeat,
                value: form.recurrenceRule == null
                    ? recurrenceText(context, '반복 안 함', 'Does not repeat')
                    : recurrenceLabel(context, form.recurrenceRule!),
                onTap: state.selectedScheduleDateTime == null
                    ? null
                    : () async {
                        final bloc = context.read<ScheduleFormBloc>();
                        final cubit = context.read<ScheduleDateTimeCubit>();
                        final owns = _captureFormOwner(context, cubit);
                        final selected =
                            await showModalBottomSheet<
                              RecurrenceSettingsResult
                            >(
                              context: context,
                              isScrollControlled: true,
                              useSafeArea: true,
                              builder: (context) => SizedBox(
                                height: MediaQuery.sizeOf(context).height * .94,
                                child: RecurrenceSettingsSheet(
                                  start: state.selectedScheduleDateTime!,
                                  timeZoneId: state.timeZoneId,
                                  initial: form.recurrenceRule,
                                  allowNone: form.originalSchedule == null,
                                  leadTime:
                                      form.totalPreparationTime +
                                      (form.moveTime ?? Duration.zero) +
                                      (form.scheduleSpareTime ?? Duration.zero),
                                ),
                              ),
                            );
                        if (selected != null && owns()) {
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
                    Text(recurrenceLabel(context, form.recurrenceRule!)),
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
            if (!state.isRecurring && state.isNonexistentCivilTime)
              TextButton(
                onPressed: () async {
                  final cubit = context.read<ScheduleDateTimeCubit>();
                  final owns = _captureFormOwner(context, cubit);
                  final civil = state.selectedScheduleDateTime;
                  if (civil == null) return;
                  final suggested = CivilTimeResolver.nextValidCivilTime(
                    civil,
                    state.timeZoneId,
                  );
                  if (suggested == null) return;
                  final occurrences = CivilTimeResolver.resolve(
                    suggested,
                    state.timeZoneId,
                  );
                  final accepted = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      scrollable: true,
                      title: Text(
                        AppLocalizations.of(context)!.zonedTimeNextValid,
                      ),
                      content: ScheduleZonedTime(
                        civil: CivilDateTime.fromFields(suggested),
                        timeZoneId: state.timeZoneId,
                        resolution: ScheduleTimeResolution(
                          status: occurrences.length == 1
                              ? ScheduleTimeResolutionStatus.resolved
                              : ScheduleTimeResolutionStatus.ambiguous,
                          instantUtc: occurrences.length == 1
                              ? occurrences.single.instantUtc
                              : null,
                          occurrences: occurrences,
                        ),
                        showInstant: true,
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(AppLocalizations.of(context)!.cancel),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(AppLocalizations.of(context)!.ok),
                        ),
                      ],
                    ),
                  );
                  if (accepted != true || !owns()) return;
                  await cubit.scheduleDateChanged(suggested);
                  if (owns()) await cubit.scheduleTimeChanged(suggested);
                },
                child: Text(AppLocalizations.of(context)!.zonedTimeNextValid),
              ),
            if (!state.isRecurring &&
                (state.hasAmbiguousCivilTime || state.requiresOccurrenceChoice))
              Padding(
                padding: const EdgeInsets.only(top: 12.0, left: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.hasAmbiguousCivilTime
                          ? _dstOverlapMessage(context)
                          : AppLocalizations.of(context)!.zonedTimeRulesChanged,
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
                            child: ScheduleZonedTime(
                              showInstant: true,
                              civil: CivilDateTime.fromFields(
                                state.selectedScheduleDateTime!,
                              ),
                              timeZoneId: state.timeZoneId,
                              resolution: ScheduleTimeResolution(
                                status: ScheduleTimeResolutionStatus.resolved,
                                instantUtc:
                                    CivilDateTime.fromFields(
                                      state.selectedScheduleDateTime!,
                                    ).atOffset(
                                      state.occurrenceOffsetOptions[index],
                                    ),
                              ),
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

String _dstGapMessage(BuildContext context) =>
    AppLocalizations.of(context)!.zonedTimeNonexistent;

String _dstOverlapMessage(BuildContext context) =>
    AppLocalizations.of(context)!.zonedTimeAmbiguous;

String _occurrenceLabel(BuildContext context, int index, int offsetSeconds) {
  final l = AppLocalizations.of(context)!;
  final occurrence = index == 0
      ? l.zonedTimeFirstOccurrence
      : l.zonedTimeSecondOccurrence;
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

bool Function() _captureFormOwner(
  BuildContext context,
  ScheduleDateTimeCubit cubit,
) {
  final bloc = cubit.scheduleFormBloc;
  final owner = bloc.formOwner;
  final mutation = bloc.state.mutationId;
  return () =>
      context.mounted &&
      !cubit.isClosed &&
      bloc.ownsForm(owner) &&
      bloc.state.mutationId == mutation;
}

ScheduleTimeResolution _selectionResolution(ScheduleDateTimeState state) {
  final civil = state.selectedScheduleDateTime;
  if (civil == null || !TimeZoneRules.contains(state.timeZoneId)) {
    return ScheduleTimeResolution(
      status: ScheduleTimeResolutionStatus.unknownZone,
    );
  }
  final candidates = CivilTimeResolver.resolve(civil, state.timeZoneId);
  final selected = candidates
      .where((c) => c.offsetSeconds == state.selectedOccurrenceOffsetSeconds)
      .firstOrNull;
  return ScheduleTimeResolution(
    status: candidates.isEmpty
        ? ScheduleTimeResolutionStatus.nonexistent
        : selected != null
        ? ScheduleTimeResolutionStatus.resolved
        : candidates.length > 1
        ? ScheduleTimeResolutionStatus.ambiguous
        : ScheduleTimeResolutionStatus.changed,
    instantUtc: selected?.instantUtc,
    occurrences: candidates,
  );
}
