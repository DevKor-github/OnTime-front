import 'package:flutter/material.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/domain/recurrence/recurring_schedule.dart';
import 'package:on_time_front/domain/use-cases/recurring_schedules_use_case.dart';
import 'package:on_time_front/presentation/recurring/recurrence_components.dart';
import 'package:on_time_front/presentation/recurring/recurrence_labels.dart';
import 'package:on_time_front/presentation/schedule_create/screens/schedule_edit_screen.dart';
import 'package:on_time_front/presentation/shared/components/modal_wide_button.dart';
import 'package:on_time_front/presentation/shared/components/two_action_dialog.dart';

class RecurringManagementScreen extends StatefulWidget {
  const RecurringManagementScreen({super.key, this.useCase});
  final RecurringSchedulesUseCase? useCase;
  @override
  State<RecurringManagementScreen> createState() =>
      _RecurringManagementScreenState();
}

class _RecurringManagementScreenState extends State<RecurringManagementScreen> {
  late final RecurringSchedulesUseCase _useCase;
  late Future<List<RecurringScheduleSummary>> _list;
  @override
  void initState() {
    super.initState();
    _useCase = widget.useCase ?? getIt<RecurringSchedulesUseCase>();
    _list = _useCase.list();
  }

  void _reload() {
    setState(() {
      _list = _useCase.list();
    });
  }

  Future<void> _open(RecurringScheduleSummary summary) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .9,
        child: _SeriesDetail(summary: summary, useCase: _useCase),
      ),
    );
    if (changed == true && mounted) _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: FutureBuilder<List<RecurringScheduleSummary>>(
      future: _list,
      builder: (context, snapshot) => RecurrenceSheet(
        title: recurrenceText(context, '반복 일정 관리', 'Recurring schedules'),
        children: [
          if (snapshot.connectionState != ConnectionState.done)
            const Center(child: CircularProgressIndicator())
          else if (snapshot.hasError) ...[
            Text(
              recurrenceText(
                context,
                '반복 일정을 불러오지 못했어요.',
                'Could not load recurring schedules.',
              ),
            ),
            TextButton(
              onPressed: _reload,
              child: Text(recurrenceText(context, '다시 시도', 'Retry')),
            ),
          ] else if (snapshot.data!.isEmpty) ...[
            Text(
              recurrenceText(
                context,
                '아직 반복 일정이 없어요.',
                'No recurring schedules yet.',
              ),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              recurrenceText(
                context,
                '일정을 만들 때 날짜·시간 단계에서 반복을 설정해 보세요.',
                'Choose Repeat in the date and time step when creating a schedule.',
              ),
            ),
          ] else ...[
            Text(
              recurrenceText(context, '반복 중인 일정', 'Active schedules'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            for (final summary in snapshot.data!.where((s) => s.next != null))
              _row(context, summary),
            if (snapshot.data!.any((s) => s.next == null))
              Text(
                recurrenceText(context, '종료된 일정', 'Ended schedules'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            for (final summary in snapshot.data!.where((s) => s.next == null))
              _row(context, summary),
          ],
        ],
      ),
    ),
  );
  Widget _row(BuildContext context, RecurringScheduleSummary summary) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      RecurrenceValue(
        label: summary.segment.schedule.scheduleName,
        value: recurrenceLabel(context, summary.segment.rule),
        onTap: () => _open(summary),
      ),
      const SizedBox(height: 8),
      Text(
        summary.next == null
            ? recurrenceText(context, '예정된 회차 없음', 'No upcoming occurrences')
            : recurrenceText(
                context,
                '다음 일정 ${recurrenceDate(context, summary.next!.scheduleTime)} · 준비 ${summary.segment.preparation.totalDuration.inMinutes}분',
                'Next ${recurrenceDate(context, summary.next!.scheduleTime)} · preparation ${summary.segment.preparation.totalDuration.inMinutes} min',
              ),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    ],
  );
}

class _SeriesDetail extends StatefulWidget {
  const _SeriesDetail({required this.summary, required this.useCase});
  final RecurringScheduleSummary summary;
  final RecurringSchedulesUseCase useCase;
  @override
  State<_SeriesDetail> createState() => _SeriesDetailState();
}

class _SeriesDetailState extends State<_SeriesDetail> {
  bool _busy = false;
  String? _error;
  Future<void> _edit() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ScheduleEditScreen(
        scheduleId: widget.summary.next!.id,
        scope: RecurringEditScope.following,
      ),
    );
    if (saved == true && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _end() async {
    final confirmed = await showTwoActionDialog(
      context,
      config: TwoActionDialogConfig(
        title: recurrenceText(context, '반복을 종료할까요?', 'End this series?'),
        description: recurrenceText(
          context,
          '다음 회차부터 개별 수정한 회차를 포함해 삭제합니다. 진행 중인 준비와 지난 기록은 유지합니다.',
          'Deletes the next and following occurrences, including individual edits. Active preparation and history are preserved.',
        ),
        secondaryAction: DialogActionConfig(
          label: recurrenceText(context, '취소', 'Cancel'),
        ),
        primaryAction: DialogActionConfig(
          label: recurrenceText(context, '반복 종료', 'End series'),
          variant: ModalWideButtonVariant.destructive,
        ),
      ),
    );
    if (confirmed != DialogActionResult.primary || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.useCase.delete(
        widget.summary.next!,
        RecurringEditScope.following,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = recurrenceText(
            context,
            '종료하지 못했어요. 다시 시도해 주세요.',
            'Could not end this series. Please retry.',
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final segment = widget.summary.segment;
    return RecurrenceSheet(
      title: recurrenceText(context, '반복 일정', 'Recurring schedule'),
      children: [
        Text(
          segment.schedule.scheduleName,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        RecurrenceValue(
          label: recurrenceText(context, '반복', 'Repeat'),
          value: recurrenceLabel(context, segment.rule),
        ),
        RecurrenceValue(
          label: recurrenceText(context, '종료 조건', 'Ends'),
          value: recurrenceEndLabel(context, segment.rule),
        ),
        if (widget.summary.next != null)
          RecurrenceValue(
            label: recurrenceText(context, '다음 일정', 'Next occurrence'),
            value: recurrenceDate(context, widget.summary.next!.scheduleTime),
          ),
        Text(
          recurrenceText(
            context,
            '이 반복 일정의 준비과정',
            'Preparation for this series',
          ),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        for (final step in segment.preparation.ordered.preparationStepList)
          Row(
            children: [
              Expanded(child: Text(step.preparationName)),
              Text(
                '${step.preparationTime.inMinutes}${recurrenceText(context, '분', ' min')}',
              ),
            ],
          ),
        if (widget.summary.next != null) ...[
          ModalWideButton(
            text: recurrenceText(
              context,
              '이후 일정 수정',
              'Edit following occurrences',
            ),
            variant: ModalWideButtonVariant.primary,
            layout: ModalWideButtonLayout.full,
            height: 52,
            onPressed: _busy ? null : _edit,
          ),
          ModalWideButton(
            text: recurrenceText(context, '반복 종료', 'End series'),
            variant: ModalWideButtonVariant.destructive,
            layout: ModalWideButtonLayout.full,
            height: 52,
            onPressed: _busy ? null : _end,
            isLoading: _busy,
          ),
        ],
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }
}
