import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:on_time_front/domain/entities/civil_date_time.dart';
import 'package:on_time_front/l10n/app_localizations.dart';

/// Edits schedule wall fields without the device's DST normalization.
Future<DateTime?> showCivilDateTimePicker({
  required BuildContext context,
  required DateTime initialCivil,
  required bool dateOnly,
  required String title,
}) {
  final carrier = CivilDateTime.fromFields(initialCivil).toUtcCarrier();
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _CivilPickerSheet(
      initialCivil: carrier,
      dateOnly: dateOnly,
      title: title,
    ),
  );
}

class _CivilPickerSheet extends StatefulWidget {
  const _CivilPickerSheet({
    required this.initialCivil,
    required this.dateOnly,
    required this.title,
  });

  final DateTime initialCivil;
  final bool dateOnly;
  final String title;

  @override
  State<_CivilPickerSheet> createState() => _CivilPickerSheetState();
}

class _CivilPickerSheetState extends State<_CivilPickerSheet> {
  late int _year, _month, _day, _hour, _minute;
  late final FixedExtentScrollController _years,
      _months,
      _days,
      _hours,
      _minutes;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialCivil;
    _year = initial.year;
    _month = initial.month;
    _day = initial.day;
    _hour = initial.hour;
    _minute = initial.minute;
    _years = FixedExtentScrollController(initialItem: _year - 1);
    _months = FixedExtentScrollController(initialItem: _month - 1);
    _days = FixedExtentScrollController(initialItem: _day - 1);
    _hours = FixedExtentScrollController(initialItem: _hour);
    _minutes = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    for (final controller in [_years, _months, _days, _hours, _minutes]) {
      controller.dispose();
    }
    super.dispose();
  }

  int get _daysInMonth => DateTime.utc(_year, _month + 1, 0).day;

  DateTime get _selection => DateTime.utc(
    _year,
    _month,
    _day,
    _hour,
    _minute,
    widget.initialCivil.second,
    widget.initialCivil.millisecond,
    widget.initialCivil.microsecond,
  );

  void _changeCalendar({int? year, int? month}) {
    final previousDay = _day;
    setState(() {
      _year = year ?? _year;
      _month = month ?? _month;
      if (_day > _daysInMonth) {
        _day = _daysInMonth;
      }
    });
    // Match the visible wheel and preview before the user can confirm a shorter
    // month. This edits only this dialog's draft, never a saved schedule.
    if (_day != previousDay && _days.hasClients) {
      _days.jumpToItem(_day - 1);
    }
  }

  Widget _wheel({
    required String name,
    required String label,
    required FixedExtentScrollController controller,
    required int count,
    required int firstValue,
    required ValueChanged<int> onChanged,
  }) {
    final extent = (MediaQuery.textScalerOf(context).scale(20) + 12)
        .clamp(44.0, 96.0)
        .toDouble();
    return Expanded(
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Expanded(
            child: Semantics(
              label: label,
              child: CupertinoPicker.builder(
                key: ValueKey('civil-picker-$name'),
                scrollController: controller,
                itemExtent: extent,
                childCount: count,
                onSelectedItemChanged: (index) => onChanged(index + firstValue),
                itemBuilder: (context, index) => Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        (index + firstValue).toString().padLeft(
                          name == 'year' ? 1 : 2,
                          '0',
                        ),
                        maxLines: 1,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final korean = locale.languageCode == 'ko';
    final wheelHeight =
        (MediaQuery.textScalerOf(context).scale(20) + 12)
                .clamp(44.0, 96.0)
                .toDouble() *
            3 +
        56;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  DateFormat.yMd(
                    locale.toString(),
                  ).add_Hms().format(_selection),
                  key: const ValueKey('civil-picker-preview'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: wheelHeight,
                child: Row(
                  children: widget.dateOnly
                      ? [
                          _wheel(
                            name: 'year',
                            label: korean ? '년' : 'Year',
                            controller: _years,
                            count: 9999,
                            firstValue: 1,
                            onChanged: (value) => _changeCalendar(year: value),
                          ),
                          _wheel(
                            name: 'month',
                            label: korean ? '월' : 'Month',
                            controller: _months,
                            count: 12,
                            firstValue: 1,
                            onChanged: (value) => _changeCalendar(month: value),
                          ),
                          _wheel(
                            name: 'day',
                            label: korean ? '일' : 'Day',
                            controller: _days,
                            count: _daysInMonth,
                            firstValue: 1,
                            onChanged: (value) {
                              if (value >= 1 &&
                                  value <= _daysInMonth &&
                                  value != _day) {
                                setState(() => _day = value);
                              }
                            },
                          ),
                        ]
                      : [
                          _wheel(
                            name: 'hour',
                            label: korean ? '시' : 'Hour',
                            controller: _hours,
                            count: 24,
                            firstValue: 0,
                            onChanged: (value) => setState(() => _hour = value),
                          ),
                          _wheel(
                            name: 'minute',
                            label: korean ? '분' : 'Minute',
                            controller: _minutes,
                            count: 60,
                            firstValue: 0,
                            onChanged: (value) =>
                                setState(() => _minute = value),
                          ),
                        ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey('civil-picker-cancel'),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        strings?.cancel ?? material.cancelButtonLabel,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey('civil-picker-confirm'),
                      onPressed: () => Navigator.pop(context, _selection),
                      child: Text(strings?.ok ?? material.okButtonLabel),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
