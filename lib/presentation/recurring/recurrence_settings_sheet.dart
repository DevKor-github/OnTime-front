import 'package:on_time_front/presentation/shared/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:on_time_front/domain/recurrence/recurrence_engine.dart';
import 'package:on_time_front/presentation/recurring/recurrence_components.dart';
import 'package:on_time_front/presentation/recurring/recurrence_labels.dart';
import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';

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
  String _page = 'settings';
  @override
  void initState() {
    super.initState();
    final r = widget.initial;
    _frequency = r?.frequency.index ?? (widget.allowNone ? -1 : 0);
    if (r == null) _page = 'frequency';
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
    bool compact = false,
  }) => TextFormField(
    controller: controller,
    style: const TextStyle(fontSize: 16),
    textAlign: compact ? TextAlign.center : TextAlign.start,
    decoration: InputDecoration(
      labelText: compact ? null : label,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
    ),
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

  void _back() {
    if (_page != 'settings') {
      setState(() => _page = 'settings');
    } else {
      Navigator.of(context).pop();
    }
  }

  Widget _heading(String ko, String en) => Text(
    recurrenceText(context, ko, en),
    style: Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
  );

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: RecurrenceSheet(
      title: recurrenceText(
        context,
        switch (_page) {
          'frequency' => '반복 단위',
          'ending' => '반복 종료',
          'monthly' => '월간 규칙 입력',
          _ => '반복 설정',
        },
        switch (_page) {
          'frequency' => 'Frequency',
          'ending' => 'Ends',
          'monthly' => 'Monthly rule',
          _ => 'Repeat',
        },
      ),
      action: recurrenceText(context, '적용', 'Apply'),
      onBack: _back,
      onAction: () {
        if (_page == 'settings' || _frequency == -1) {
          _apply();
        } else if (_form.currentState!.validate()) {
          setState(() => _page = 'settings');
        }
      },
      children: [
        if (_page == 'frequency')
          ..._frequencyFields()
        else if (_page == 'ending')
          ..._endingFields()
        else if (_page == 'monthly')
          ..._monthlyFields()
        else
          ..._settingsFields(),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    ),
  );

  List<Widget> _frequencyFields() => [
    for (var i = widget.allowNone ? -1 : 0; i < 3; i++)
      RecurrenceChoice(
        label: recurrenceText(
          context,
          i == -1 ? '반복 안 함' : ['매일', '매주', '매월'][i],
          i == -1 ? 'Does not repeat' : ['Daily', 'Weekly', 'Monthly'][i],
        ),
        selected: _frequency == i,
        onTap: () => setState(() {
          _frequency = i;
          _error = null;
        }),
      ),
    if (_frequency >= 0) ...[
      const SizedBox(height: 8),
      _number(
        _interval,
        recurrenceText(
          context,
          '간격 (${['일', '주', '월'][_frequency]})',
          'Interval',
        ),
      ),
      Text(
        recurrenceText(
          context,
          '첫 일정부터 선택한 간격으로 반복됩니다.',
          'Repeats at the selected interval from the first occurrence.',
        ),
      ),
    ],
  ];

  List<Widget> _settingsFields() => [
    Text(
      recurrenceText(
        context,
        '일정을 언제, 얼마나 자주 반복할지 설정하세요.',
        'Choose when and how often to repeat.',
      ),
      style: Theme.of(context).textTheme.bodySmall,
    ),
    _heading('반복 단위', 'Frequency'),
    Row(
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 44),
                backgroundColor: _frequency == i
                    ? AppColors.blue.shade600
                    : Theme.of(context).colorScheme.surfaceContainerLowest,
                foregroundColor: _frequency == i
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => setState(() {
                _frequency = i;
                _error = null;
              }),
              child: Text(
                recurrenceText(
                  context,
                  ['일', '주', '월'][i],
                  ['Day', 'Week', 'Month'][i],
                ),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ],
      ],
    ),
    if (_frequency >= 0) ...[
      _heading('${['일', '주', '월'][_frequency]} 반복 간격', 'Repeat interval'),
      Row(
        children: [
          Text(recurrenceText(context, '매', 'Every')),
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            child: _number(
              _interval,
              recurrenceText(context, '간격', 'Interval'),
              compact: true,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              recurrenceText(
                context,
                '${['일', '주', '개월'][_frequency]}마다 반복',
                ['days', 'weeks', 'months'][_frequency],
              ),
            ),
          ),
        ],
      ),
      if (_frequency == 1) ...[
        _heading('반복 요일', 'Repeat on'),
        LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: constraints.maxWidth >= 344
                ? (constraints.maxWidth - 7 * 44) / 6
                : 6,
            runSpacing: 8,
            children: [
              for (var day = 1; day <= 7; day++)
                Semantics(
                  key: ValueKey('recurrence-weekday-$day'),
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
                            ? AppColors.blue.shade600
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
                      child: Text(
                        weekdayLabel(context, day),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
      if (_frequency == 2)
        RecurrenceValue(
          label: recurrenceText(context, '월 규칙', 'Monthly rule'),
          value: recurrenceText(context, switch (_monthly) {
            MonthlyRecurrence.dayOfMonth => '매월 ${_monthDay.text}일',
            MonthlyRecurrence.nthWeekday =>
              '${_ordinal == -1 ? '마지막' : '$_ordinal번째'} ${weekdayLabel(context, _monthWeekday)}요일',
            MonthlyRecurrence.lastDay => '매월 마지막 날',
          }, 'Configure monthly rule'),
          onTap: () => setState(() => _page = 'monthly'),
        ),
      _heading('종료 조건', 'Ends'),
      RecurrenceValue(
        label: recurrenceText(context, '반복 종료', 'Repeat ends'),
        compact: true,
        value: recurrenceText(
          context,
          _end == 0
              ? '종료 없음'
              : _end == 1
              ? recurrenceDay(context, _until)
              : '총 ${_count.text}회',
          _end == 0
              ? 'Never'
              : _end == 1
              ? recurrenceDay(context, _until)
              : 'After ${_count.text} occurrences',
        ),
        onTap: () => setState(() => _page = 'ending'),
      ),
      RecurrencePanel(
        highlighted: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              recurrenceText(context, '반복 예시', 'Preview'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.blue.shade600,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _preview(),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.8),
            ),
          ],
        ),
      ),
    ],
    if (widget.allowNone)
      TextButton(
        onPressed: () => setState(() => _page = 'frequency'),
        child: Text(
          recurrenceText(
            context,
            '반복 단위 변경 / 반복 안 함',
            'Change frequency / do not repeat',
          ),
          style: const TextStyle(fontSize: 12),
        ),
      ),
  ];

  String _preview() {
    try {
      return '${recurrenceLabel(context, _rule())}\n${_first()}';
    } catch (_) {
      return _first();
    }
  }

  List<Widget> _monthlyFields() => [
    _heading('반복 방식', 'Repeat pattern'),
    RecurrenceChoice(
      label: recurrenceText(context, '매월 특정 날짜에 반복', 'Day of month'),
      description: recurrenceText(
        context,
        '예) 매월 10일',
        'For example, the 10th',
      ),
      selected: _monthly == MonthlyRecurrence.dayOfMonth,
      onTap: () => setState(() => _monthly = MonthlyRecurrence.dayOfMonth),
      child: _monthly == MonthlyRecurrence.dayOfMonth
          ? _number(
              _monthDay,
              recurrenceText(context, '매월 며칠', 'Day of month'),
              day: true,
            )
          : null,
    ),
    RecurrenceChoice(
      label: recurrenceText(context, '특정 순번의 요일에 반복', 'Nth weekday'),
      description: recurrenceText(
        context,
        '예) 두 번째 수요일',
        'For example, the second Wednesday',
      ),
      selected: _monthly == MonthlyRecurrence.nthWeekday && _ordinal != -1,
      onTap: () => setState(() {
        _monthly = MonthlyRecurrence.nthWeekday;
        if (_ordinal == -1) _ordinal = 1;
      }),
    ),
    if (_monthly == MonthlyRecurrence.nthWeekday && _ordinal != -1)
      Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: _ordinal,
              decoration: InputDecoration(
                labelText: recurrenceText(context, '순번', 'Ordinal'),
              ),
              items: [
                for (var n = 1; n <= 5; n++)
                  DropdownMenuItem(
                    value: n,
                    child: Text(recurrenceText(context, '$n번째', '#$n')),
                  ),
              ],
              onChanged: (v) => setState(() => _ordinal = v!),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(child: _weekdayField()),
        ],
      ),
    RecurrenceChoice(
      label: recurrenceText(context, '매월 마지막 날에 반복', 'Last day of month'),
      selected: _monthly == MonthlyRecurrence.lastDay,
      onTap: () => setState(() => _monthly = MonthlyRecurrence.lastDay),
    ),
    RecurrenceChoice(
      label: recurrenceText(
        context,
        '특정 요일의 마지막 날에 반복',
        'Last weekday of month',
      ),
      selected: _monthly == MonthlyRecurrence.nthWeekday && _ordinal == -1,
      onTap: () => setState(() {
        _monthly = MonthlyRecurrence.nthWeekday;
        _ordinal = -1;
      }),
      child: _monthly == MonthlyRecurrence.nthWeekday && _ordinal == -1
          ? _weekdayField()
          : null,
    ),
    RecurrencePanel(
      child: Text(
        recurrenceText(
          context,
          '해당 월에 선택한 날짜나 순번이 없으면 자동으로 건너뜁니다. 건너뛴 날짜는 총횟수에 포함하지 않아요.',
          'Missing dates and fifth weekdays are skipped without consuming the count.',
        ),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ),
  ];

  Widget _weekdayField() => DropdownButtonFormField<int>(
    initialValue: _monthWeekday,
    decoration: InputDecoration(
      labelText: recurrenceText(context, '요일', 'Weekday'),
    ),
    items: [
      for (var d = 1; d <= 7; d++)
        DropdownMenuItem(value: d, child: Text(weekdayLabel(context, d))),
    ],
    onChanged: (v) => setState(() => _monthWeekday = v!),
  );

  List<Widget> _endingFields() => [
    Text(
      recurrenceText(
        context,
        '언제까지 반복할지 선택하세요.',
        'Choose when the series ends.',
      ),
    ),
    for (var i = 0; i < 3; i++)
      RecurrenceChoice(
        label: recurrenceText(
          context,
          ['종료 없음', '날짜 지정', '총횟수'][i],
          ['Never', 'On date', 'After count'][i],
        ),
        description: recurrenceText(
          context,
          ['계속 반복합니다.', '지정한 날짜까지 반복합니다.', '지정한 횟수만큼 반복합니다.'][i],
          [
            'Keeps repeating.',
            'Includes the selected date.',
            'Repeats for the selected count.',
          ][i],
        ),
        selected: _end == i,
        onTap: () => setState(() => _end = i),
        child: i == 2 && _end == 2
            ? _number(
                _count,
                recurrenceText(context, '반복 횟수', 'Occurrence count'),
              )
            : null,
      ),
    if (_end == 1)
      RecurrenceValue(
        label: recurrenceText(context, '마지막 날짜', 'Inclusive end date'),
        value: recurrenceDay(context, _until),
        icon: Icons.calendar_today_outlined,
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
          if (picked != null && mounted) setState(() => _until = picked);
        },
      ),
    RecurrencePanel(
      highlighted: _end == 1,
      child: Text(
        recurrenceText(
          context,
          _end == 1
              ? '지정한 날짜가 포함되어 반복이 종료됩니다. 일정의 시간대를 기준으로 적용됩니다.'
              : '실제로 존재하는 회차만 횟수에 포함됩니다. 삭제한 회차는 보충되지 않습니다.',
          _end == 1
              ? 'The end date is inclusive, in the schedule time zone.'
              : 'Only existing occurrences count. Deleted occurrences are not replaced.',
        ),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ),
  ];
}
