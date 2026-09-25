import 'package:on_time_front/presentation/calendar/component/schedule_deletion_dialog.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/domain/recurrence/recurring_schedule.dart';
import 'package:on_time_front/domain/use-cases/recurring_schedules_use_case.dart';
import 'package:on_time_front/presentation/recurring/recurrence_components.dart';
import 'package:on_time_front/presentation/recurring/recurrence_labels.dart';
import 'package:on_time_front/presentation/schedule_create/screens/schedule_edit_screen.dart';
import 'package:on_time_front/presentation/shared/components/modal_wide_button.dart';

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
        height: MediaQuery.sizeOf(context).height * .94,
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
        footer: snapshot.hasData && snapshot.data!.isEmpty
            ? ScreenActions(
                action: recurrenceText(context, '약속 추가', 'Add appointment'),
                onAction: () async {
                  await context.push('/scheduleCreate');
                  if (mounted) _reload();
                },
              )
            : null,
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
            RecurrencePanel(
              highlighted: true,
              child: Text(
                recurrenceText(
                  context,
                  '약속을 생성할 때 날짜·시간 단계에서 반복을 설정할 수 있습니다. 반복으로 등록하면 각 일정별 준비과정도 함께 관리할 수 있습니다.',
                  'Choose Repeat in the date and time step when creating a schedule. Each series has its own preparation.',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              recurrenceText(
                context,
                '등록된 반복 일정 · 0개',
                'Recurring schedules · 0',
              ),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            RecurrencePanel(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 44),
              child: Text(
                recurrenceText(
                  context,
                  '아직 등록된 반복 일정이 없습니다.\n지금 약속을 추가하고 반복 일정을 관리해보세요.',
                  'No recurring schedules yet.\nAdd an appointment to get started.',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ] else ...[
            Text(
              recurrenceText(context, '반복 중인 일정', 'Active schedules'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            for (final summary in snapshot.data!.where((s) => s.next != null))
              _row(context, summary),
            if (snapshot.data!.any((s) => s.next == null))
              Text(
                recurrenceText(context, '종료된 일정', 'Ended schedules'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            for (final summary in snapshot.data!.where((s) => s.next == null))
              _row(context, summary),
          ],
        ],
      ),
    ),
  );
  Widget _row(
    BuildContext context,
    RecurringScheduleSummary summary,
  ) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLowest,
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      onTap: () => _open(summary),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary.segment.schedule.scheduleName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    recurrenceLabel(context, summary.segment.rule),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    summary.next == null
                        ? recurrenceText(
                            context,
                            '예정된 회차 없음',
                            'No upcoming occurrences',
                          )
                        : recurrenceText(
                            context,
                            '다음 일정 ${recurrenceDate(context, summary.next!.scheduleTime)} · 준비 ${summary.segment.preparation.totalDuration.inMinutes}분',
                            'Next ${recurrenceDate(context, summary.next!.scheduleTime)} · preparation ${summary.segment.preparation.totalDuration.inMinutes} min',
                          ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    ),
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
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final changed = await showScheduleDeletionDialog(
        context,
        schedule: widget.summary.next!,
        deletions: widget.useCase.deletions,
        scope: RecurringEditScope.following,
      );
      if (changed && mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final segment = widget.summary.segment;
    return RecurrenceSheet(
      title: segment.schedule.scheduleName,
      spacing: 10,
      footer: ScreenActions(
        action: recurrenceText(context, '뒤로', 'Back'),
        onAction: () => Navigator.of(context).pop(),
      ),
      children: [
        RecurrencePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                recurrenceText(context, '반복 규칙', 'Repeat'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              Text(
                recurrenceLabel(context, segment.rule),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                recurrenceEndLabel(context, segment.rule),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (widget.summary.next != null) ...[
                const SizedBox(height: 16),
                Text(
                  recurrenceText(context, '다음 일정', 'Next occurrence'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Text(
                  recurrenceDate(context, widget.summary.next!.scheduleTime),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ],
          ),
        ),
        Text(
          recurrenceText(context, '전용 준비', 'Preparation for this series'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        for (final step in segment.preparation.ordered.preparationStepList)
          RecurrencePanel(
            child: Row(
              children: [
                Expanded(child: Text(step.preparationName)),
                Text(
                  '${step.preparationTime.inMinutes}${recurrenceText(context, '분', ' min')}',
                ),
              ],
            ),
          ),
        const Divider(height: 24),
        Text(
          recurrenceText(context, '독립 관리 안내', 'Manage independently'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Text(
          recurrenceText(
            context,
            '반복 규칙과 준비 과정은 각각 독립적으로 관리할 수 있어요. 필요에 따라 따로 수정할 수 있습니다.',
            'You can edit the recurrence rule and preparation independently.',
          ),
        ),
        if (widget.summary.next != null) ...[
          ModalWideButton(
            text: recurrenceText(context, '반복 규칙 수정', 'Edit recurrence'),
            variant: ModalWideButtonVariant.subtle,
            layout: ModalWideButtonLayout.full,
            height: 48,
            onPressed: _busy ? null : _edit,
          ),
          ModalWideButton(
            text: recurrenceText(context, '준비과정 수정', 'Edit preparation'),
            variant: ModalWideButtonVariant.subtle,
            layout: ModalWideButtonLayout.full,
            height: 48,
            onPressed: _busy ? null : _edit,
          ),
          const Divider(),
          ModalWideButton(
            text: recurrenceText(context, '반복 종료', 'End series'),
            variant: ModalWideButtonVariant.neutral,
            layout: ModalWideButtonLayout.full,
            height: 48,
            onPressed: _busy ? null : _end,
          ),
        ],
      ],
    );
  }
}
