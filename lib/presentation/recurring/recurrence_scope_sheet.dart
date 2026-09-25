import 'package:flutter/material.dart';
import 'package:on_time_front/domain/recurrence/recurring_schedule.dart';
import 'package:on_time_front/presentation/recurring/recurrence_components.dart';
import 'package:on_time_front/presentation/recurring/recurrence_labels.dart';

Future<RecurringEditScope?> showRecurrenceScope(
  BuildContext context, {
  bool deleting = false,
}) => showModalBottomSheet<RecurringEditScope>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .94,
    child: _ScopeSheet(deleting: deleting),
  ),
);

class _ScopeSheet extends StatefulWidget {
  const _ScopeSheet({required this.deleting});
  final bool deleting;
  @override
  State<_ScopeSheet> createState() => _ScopeSheetState();
}

class _ScopeSheetState extends State<_ScopeSheet> {
  var _scope = RecurringEditScope.occurrence;
  @override
  Widget build(BuildContext context) => RecurrenceSheet(
    title: recurrenceText(
      context,
      widget.deleting ? '삭제 범위' : '변경 범위',
      widget.deleting ? 'Delete scope' : 'Edit scope',
    ),
    spacing: 10,
    footer: ScreenActions(
      action: recurrenceText(
        context,
        widget.deleting ? '선택한 범위 삭제' : '선택한 범위로 수정',
        widget.deleting ? 'Delete selected scope' : 'Edit selected scope',
      ),
      destructive: widget.deleting,
      onBack: () => Navigator.of(context).pop(),
      onAction: () => Navigator.of(context).pop(_scope),
    ),
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 11),
        child: Text(
          recurrenceText(
            context,
            '어떤 일정까지 변경할지 선택해 주세요.',
            'Which occurrences?',
          ),
          style: const TextStyle(
            fontSize: 14,
            height: 1.6,
            color: Color(0xff545454),
          ),
        ),
      ),
      for (final scope in RecurringEditScope.values)
        RecurrenceChoice(
          label: recurrenceText(
            context,
            scope == RecurringEditScope.occurrence ? '이번 일정만' : '이번 및 이후 일정',
            scope == RecurringEditScope.occurrence
                ? 'This occurrence'
                : 'This and following',
          ),
          description: recurrenceText(
            context,
            scope == RecurringEditScope.occurrence
                ? '선택한 이번 일정만 수정하거나 삭제합니다.'
                : '이번 일정부터 이후의 모든 일정을 수정하거나 삭제합니다.',
            scope == RecurringEditScope.occurrence
                ? 'Applies only to the selected occurrence.'
                : 'Applies to this and all following occurrences.',
          ),
          selected: _scope == scope,
          onTap: () => setState(() => _scope = scope),
        ),
      Padding(
        padding: const EdgeInsets.only(top: 16),
        child: RecurrenceNotice(
          bare: true,
          child: Text(
            recurrenceText(
              context,
              widget.deleting
                  ? '이후 삭제에는 개별 수정한 회차도 포함돼요. 진행 중·과거 회차는 유지합니다.'
                  : '이미 진행 중이거나 완료된 회차는 변경되지 않으며,\n이전에 개별적으로 수정한 항목도 그대로 유지됩니다.',
              widget.deleting
                  ? 'Following occurrences include individual edits. Active and historical occurrences are preserved.'
                  : 'Individual overrides, active preparations and history are preserved.',
            ),
            style: const TextStyle(
              fontSize: 12,
              height: 1.6,
              color: Color(0xff545454),
            ),
          ),
        ),
      ),
    ],
  );
}
