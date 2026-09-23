import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:on_time_front/domain/recurrence/recurrence_engine.dart';
import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';
import 'package:on_time_front/presentation/recurring/recurrence_components.dart';
import 'package:on_time_front/presentation/recurring/recurrence_labels.dart';

class RecurrenceSettingsResult {
  const RecurrenceSettingsResult(this.rule, this.countChanged);
  final RecurrenceRule? rule;
  final bool countChanged;
}

class RecurrenceSettingsSheet extends StatefulWidget {
  const RecurrenceSettingsSheet({
    super.key,
    required this.start,
    required this.timeZoneId,
    this.initial,
    this.allowNone = true,
    this.leadTime = Duration.zero,
  });
  final DateTime start;
  final String timeZoneId;
  final RecurrenceRule? initial;
  final bool allowNone;
  final Duration leadTime;
  @override
  State<RecurrenceSettingsSheet> createState() =>
      _RecurrenceSettingsSheetState();
}

class _RecurrenceSettingsSheetState extends State<RecurrenceSettingsSheet> {
  final _form = GlobalKey<FormState>();
  late int _frequency;
  late final TextEditingController _interval;
  late final TextEditingController _count;
  late final TextEditingController _monthDay;
  late Set<int> _weekdays;
  late MonthlyRecurrence _monthly;
  late int _ordinal;
  late int _monthWeekday;
  late int _end;
  late DateTime _until;
  String? _error;
  @override
  void initState() {
    super.initState();
    final r = widget.initial;
    _frequency = r?.frequency.index ?? -1;
    _interval = TextEditingController(text: '${r?.interval ?? 1}');
    _count = TextEditingController(text: '${r?.count ?? 10}');
    _monthDay = TextEditingController(
      text: '${r?.monthDay ?? widget.start.day}',
    );
    _weekdays = {
      ...r?.weekdays ?? {widget.start.weekday},
    };
    _monthly = r?.monthly ?? MonthlyRecurrence.dayOfMonth;
    _ordinal = r?.ordinal ?? 1;
    _monthWeekday = r?.monthWeekday ?? widget.start.weekday;
    _end = r?.count != null
        ? 2
        : r?.until != null
        ? 1
        : 0;
    _until =
        r?.until ??
        DateTime(widget.start.year, widget.start.month + 3, widget.start.day);
  }

  @override
  void dispose() {
    _interval.dispose();
    _count.dispose();
    _monthDay.dispose();
    super.dispose();
  }

  RecurrenceRule _rule() => RecurrenceRule(
    frequency: RecurrenceFrequency.values[_frequency],
    start: widget.start,
    timeZoneId: widget.timeZoneId,
    interval: int.parse(_interval.text),
    weekdays: _weekdays,
    monthly: _monthly,
    monthDay: _frequency == 2 && _monthly == MonthlyRecurrence.dayOfMonth
        ? int.parse(_monthDay.text)
        : widget.start.day,
    ordinal: _ordinal,
    monthWeekday: _monthWeekday,
    count: _end == 2 ? int.parse(_count.text) : null,
    until: _end == 1 ? _until : null,
    repeatedTime: widget.initial?.repeatedTime,
  );

  void _apply() {
    if (_frequency == -1) {
      Navigator.of(context).pop(const RecurrenceSettingsResult(null, false));
      return;
    }
    if (!_form.currentState!.validate()) return;
    if (_frequency == 1 && _weekdays.isEmpty) {
      setState(
        () => _error = recurrenceText(
          context,
          '요일을 하나 이상 선택해 주세요.',
          'Select at least one weekday.',
        ),
      );
      return;
    }
    try {
      final rule = _rule();
      Navigator.of(context).pop(
        RecurrenceSettingsResult(
          rule,
          rule.count != widget.initial?.count ||
              rule.until != widget.initial?.until,
        ),
      );
    } catch (_) {
      setState(
        () => _error = recurrenceText(
          context,
          '시작 날짜와 종료 조건을 확인해 주세요.',
          'Check the start and end conditions.',
        ),
      );
    }
  }

  String? _positive(String? value) => (int.tryParse(value ?? '') ?? 0) < 1
      ? recurrenceText(context, '1 이상 입력해 주세요.', 'Enter 1 or more.')
      : null;
  Widget _number(
    TextEditingController controller,
    String label, {
    bool day = false,
  }) => TextFormField(
    controller: controller,
    decoration: InputDecoration(labelText: label),
    keyboardType: TextInputType.number,
    inputFormatters: [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(6),
    ],
    validator: (v) =>
        _positive(v) ??
        (day && int.parse(v!) > 31
            ? recurrenceText(context, '31 이하로 입력해 주세요.', 'Enter 31 or less.')
            : null),
    onChanged: (_) => setState(() => _error = null),
  );
  String _first() {
    try {
      final r = _rule();
      final slots = const RecurrenceEngine()
          .expand(
            r,
            through: r.until ?? DateTime(widget.start.year + 50, 12, 31),
            preparationNotBeforeUtc: DateTime.now(),
            leadTime: widget.leadTime,
            limit: 1,
          )
          .slots;
      return slots.isEmpty
          ? recurrenceText(
              context,
              '이 조건에 해당하는 일정이 없어요.',
              'No matching occurrence.',
            )
          : '${recurrenceText(context, '첫 일정', 'First occurrence')} · ${recurrenceDate(context, slots.first.civilTime)}';
    } on RepeatedTimeChoiceRequired {
      return recurrenceText(
        context,
        '두 번 발생하는 시각은 저장 전에 선택해요.',
        'Choose the repeated time before saving.',
      );
    } catch (_) {
      return recurrenceText(
        context,
        '반복 조건을 입력해 주세요.',
        'Enter the recurrence conditions.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: RecurrenceSheet(
      title: recurrenceText(context, '반복 설정', 'Repeat'),
      action: recurrenceText(context, '적용', 'Apply'),
      onAction: _apply,
      children: [
        DropdownButtonFormField<int>(
          initialValue: _frequency,
          decoration: InputDecoration(
            labelText: recurrenceText(context, '반복 단위', 'Frequency'),
          ),
          items: [
            if (widget.allowNone)
              DropdownMenuItem(
                value: -1,
                child: Text(
                  recurrenceText(context, '반복 안 함', 'Does not repeat'),
                ),
              ),
            for (var i = 0; i < 3; i++)
              DropdownMenuItem(
                value: i,
                child: Text(
                  recurrenceText(
                    context,
                    ['매일', '매주', '매월'][i],
                    ['Daily', 'Weekly', 'Monthly'][i],
                  ),
                ),
              ),
          ],
          onChanged: (v) => setState(() => _frequency = v!),
        ),
        if (_frequency != -1) ...[
          _number(
            _interval,
            recurrenceText(
              context,
              '간격 (${['일', '주', '개월'][_frequency]})',
              'Interval (${['days', 'weeks', 'months'][_frequency]})',
            ),
          ),
          if (_frequency == 1) ...[
            Text(
              recurrenceText(context, '반복할 요일', 'Repeat on'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var day = 1; day <= 7; day++)
                  Semantics(
                    selected: _weekdays.contains(day),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(44, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          backgroundColor: _weekdays.contains(day)
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerLowest,
                          foregroundColor: _weekdays.contains(day)
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                        onPressed: () => setState(() {
                          _weekdays.contains(day)
                              ? _weekdays.remove(day)
                              : _weekdays.add(day);
                          _error = null;
                        }),
                        child: Text(weekdayLabel(context, day)),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (_frequency == 2) ...[
            for (final option in MonthlyRecurrence.values)
              RecurrenceChoice(
                label: recurrenceText(
                  context,
                  switch (option) {
                    MonthlyRecurrence.dayOfMonth => '날짜로 반복',
                    MonthlyRecurrence.nthWeekday => '몇 번째 요일 / 마지막 요일',
                    MonthlyRecurrence.lastDay => '매월 마지막 날',
                  },
                  switch (option) {
                    MonthlyRecurrence.dayOfMonth => 'Day of month',
                    MonthlyRecurrence.nthWeekday => 'Nth or last weekday',
                    MonthlyRecurrence.lastDay => 'Last day of month',
                  },
                ),
                selected: _monthly == option,
                onTap: () => setState(() => _monthly = option),
              ),
            if (_monthly == MonthlyRecurrence.dayOfMonth)
              _number(
                _monthDay,
                recurrenceText(context, '매월 며칠', 'Day of month'),
                day: true,
              ),
            if (_monthly == MonthlyRecurrence.nthWeekday) ...[
              DropdownButtonFormField<int>(
                initialValue: _ordinal,
                decoration: InputDecoration(
                  labelText: recurrenceText(context, '순서', 'Ordinal'),
                ),
                items: [
                  for (final n in [1, 2, 3, 4, 5, -1])
                    DropdownMenuItem(
                      value: n,
                      child: Text(
                        n == -1
                            ? recurrenceText(context, '마지막', 'Last')
                            : recurrenceText(context, '$n번째', '#$n'),
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _ordinal = v!),
              ),
              DropdownButtonFormField<int>(
                initialValue: _monthWeekday,
                decoration: InputDecoration(
                  labelText: recurrenceText(context, '요일', 'Weekday'),
                ),
                items: [
                  for (var d = 1; d <= 7; d++)
                    DropdownMenuItem(
                      value: d,
                      child: Text(weekdayLabel(context, d)),
                    ),
                ],
                onChanged: (v) => setState(() => _monthWeekday = v!),
              ),
            ],
            Text(
              recurrenceText(
                context,
                '없는 날짜나 다섯 번째 요일은 건너뛰고 총횟수에 포함하지 않아요.',
                'Missing dates and fifth weekdays are skipped without consuming the count.',
              ),
            ),
          ],
          DropdownButtonFormField<int>(
            initialValue: _end,
            decoration: InputDecoration(
              labelText: recurrenceText(context, '반복 종료', 'Ends'),
            ),
            items: [
              for (var i = 0; i < 3; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text(
                    recurrenceText(
                      context,
                      ['종료 없음', '날짜 지정', '횟수 지정'][i],
                      ['Never', 'On date', 'After count'][i],
                    ),
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _end = v!),
          ),
          if (_end == 2)
            _number(
              _count,
              recurrenceText(context, '반복 횟수', 'Occurrence count'),
            ),
          if (_end == 1)
            RecurrenceValue(
              label: recurrenceText(context, '이 날짜까지 포함', 'Inclusive end date'),
              value: recurrenceDay(context, _until),
              onTap: () async {
                final day = DateTime(
                  widget.start.year,
                  widget.start.month,
                  widget.start.day,
                );
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _until.isBefore(day) ? day : _until,
                  firstDate: day,
                  lastDate: DateTime(9999, 12, 31),
                );
                if (picked != null) setState(() => _until = picked);
              },
            ),
          Text(
            _first(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    ),
  );
}
