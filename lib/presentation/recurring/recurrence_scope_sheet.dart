import 'package:flutter/material.dart';
import 'package:on_time_front/domain/recurrence/recurring_schedule.dart';
import 'package:on_time_front/presentation/recurring/recurrence_components.dart';
import 'package:on_time_front/presentation/recurring/recurrence_labels.dart';
import 'package:on_time_front/presentation/shared/components/modal_wide_button.dart';

Future<RecurringEditScope?> showRecurrenceScope(
  BuildContext context, {
  bool deleting = false,
}) => showModalBottomSheet<RecurringEditScope>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) =>
      SizedBox(height: 440, child: _ScopeSheet(deleting: deleting)),
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
    children: [
      Text(
        recurrenceText(context, '어떤 일정에 적용할까요?', 'Which occurrences?'),
        style: Theme.of(context).textTheme.titleLarge,
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
          selected: _scope == scope,
          onTap: () => setState(() => _scope = scope),
        ),
      Text(
        recurrenceText(
          context,
          widget.deleting
              ? '이후 삭제에는 개별 수정한 회차도 포함돼요. 진행 중·과거 회차는 유지합니다.'
              : '개별 수정한 항목과 진행 중·과거 회차는 유지합니다.',
          widget.deleting
              ? 'Following occurrences include individual edits. Active and historical occurrences are preserved.'
              : 'Individual overrides, active preparations and history are preserved.',
        ),
      ),
      ModalWideButton(
        text: recurrenceText(
          context,
          widget.deleting ? '선택한 범위 삭제' : '선택한 범위로 수정',
          widget.deleting ? 'Delete selected scope' : 'Edit selected scope',
        ),
        variant: widget.deleting
            ? ModalWideButtonVariant.destructive
            : ModalWideButtonVariant.primary,
        layout: ModalWideButtonLayout.full,
        height: 52,
        onPressed: () => Navigator.of(context).pop(_scope),
      ),
    ],
  );
}
