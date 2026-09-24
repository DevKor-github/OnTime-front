import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/domain/recurrence/recurring_schedule.dart';
import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';
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

  Future<void> _create() async {
    final saved = await context.push<bool>('/scheduleCreate');
    if (saved == true && mounted) _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      centerTitle: true,
      toolbarHeight: 36,
      leadingWidth: 48,
      leading: IconButton(
        tooltip: recurrenceText(context, '뒤로', 'Back'),
        onPressed: () => Navigator.of(context).pop(),
        icon: SvgPicture.asset('chevron_left.svg', package: 'assets'),
      ),
      title: Text(
        recurrenceText(context, '반복 일정 관리', 'Recurring schedules'),
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(7),
        child: Column(
          children: [
            SizedBox(height: 6),
            Divider(height: 1, thickness: 1, color: Color(0xff949494)),
          ],
        ),
      ),
    ),
    body: FutureBuilder<List<RecurringScheduleSummary>>(
      future: _list,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
              ],
            ),
          );
        }
        final schedules = snapshot.data!;
        if (schedules.isEmpty) {
          return _RecurringEmptyView(onCreate: _create);
        }
        final active = schedules.where((s) => s.next != null).toList();
        final ended = schedules.where((s) => s.next == null).toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            _RecurringSectionTitle(
              title: recurrenceText(
                context,
                '진행 중인 반복 일정',
                'Active recurring schedules',
              ),
              count: active.length,
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < active.length; i++) ...[
              _RecurringScheduleCard(
                summary: active[i],
                onTap: () => _open(active[i]),
              ),
              if (i != active.length - 1) const SizedBox(height: 13),
            ],
            if (ended.isNotEmpty) ...[
              const SizedBox(height: 33),
              _RecurringSectionTitle(
                title: recurrenceText(
                  context,
                  '종료된 반복 일정',
                  'Ended recurring schedules',
                ),
                count: ended.length,
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < ended.length; i++) ...[
                _RecurringScheduleCard(
                  summary: ended[i],
                  onTap: () => _open(ended[i]),
                ),
                if (i != ended.length - 1) const SizedBox(height: 13),
              ],
            ],
          ],
        );
      },
    ),
  );
}

class _RecurringSectionTitle extends StatelessWidget {
  const _RecurringSectionTitle({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 26,
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          '$count${recurrenceText(context, '개', '')}',
          style: const TextStyle(fontSize: 14, color: Color(0xff545454)),
        ),
      ],
    ),
  );
}

class _RecurringScheduleCard extends StatelessWidget {
  const _RecurringScheduleCard({required this.summary, required this.onTap});

  final RecurringScheduleSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final next = summary.next;
    return Material(
      key: ValueKey('recurring_card_${summary.segment.id}'),
      color: const Color(0xfff6f6f6),
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: next == null ? 71 : 99),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.segment.schedule.scheduleName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (next == null)
                        Text(
                          _endedLabel(context, summary.segment.rule),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xff545454),
                          ),
                        )
                      else ...[
                        Text(
                          _compactRule(context, summary.segment.rule),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xff545454),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 4,
                          runSpacing: 2,
                          children: [
                            SvgPicture.asset(
                              'recurring_card_calendar.svg',
                              package: 'assets',
                            ),
                            Text(
                              recurrenceText(context, '다음 일정', 'Next'),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xff545454),
                              ),
                            ),
                            Text(
                              DateFormat('M/d').format(next.scheduleTime),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xff545454),
                              ),
                            ),
                            const SizedBox(
                              width: 1,
                              height: 12,
                              child: ColoredBox(color: Color(0xff949494)),
                            ),
                            SvgPicture.asset(
                              'recurring_card_clock.svg',
                              package: 'assets',
                            ),
                            Text(
                              recurrenceText(
                                context,
                                '준비 ${summary.segment.preparation.totalDuration.inMinutes}분',
                                'Prep ${summary.segment.preparation.totalDuration.inMinutes} min',
                              ),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xff545454),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                SvgPicture.asset(
                  'recurring_card_chevron.svg',
                  package: 'assets',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _endedLabel(BuildContext context, RecurrenceRule rule) {
    final until = rule.until;
    final suffix = until == null ? '' : ' · ${DateFormat('M/d').format(until)}';
    return '${recurrenceText(context, '종료됨', 'Ended')}$suffix';
  }

  String _compactRule(BuildContext context, RecurrenceRule rule) {
    if (Localizations.localeOf(context).languageCode != 'ko') {
      return recurrenceLabel(context, rule);
    }
    final frequency = switch (rule.frequency) {
      RecurrenceFrequency.daily =>
        rule.interval == 1 ? '매일' : '${rule.interval}일마다',
      RecurrenceFrequency.weekly =>
        rule.interval == 1 ? '매주' : '${rule.interval}주마다',
      RecurrenceFrequency.monthly =>
        rule.interval == 1 ? '매월' : '${rule.interval}개월마다',
    };
    final detail = switch (rule.frequency) {
      RecurrenceFrequency.daily => '',
      RecurrenceFrequency.weekly =>
        (rule.weekdays.toList()..sort())
            .map((day) => weekdayLabel(context, day))
            .join(' · '),
      RecurrenceFrequency.monthly => switch (rule.monthly) {
        MonthlyRecurrence.dayOfMonth => '${rule.monthDay}일',
        MonthlyRecurrence.lastDay => '마지막 날',
        MonthlyRecurrence.nthWeekday =>
          '${rule.ordinal == -1 ? '마지막' : '${rule.ordinal}번째'} ${weekdayLabel(context, rule.monthWeekday)}요일',
      },
    };
    final time = rule.start.minute == 0
        ? '${rule.start.hour}시'
        : '${rule.start.hour}시 ${rule.start.minute}분';
    return [frequency, if (detail.isNotEmpty) detail, time].join(' ');
  }
}

class _RecurringEmptyView extends StatelessWidget {
  const _RecurringEmptyView({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 11, 20, 14),
              child: Column(
                children: [
                  Container(
                    key: const Key('recurring_empty_info'),
                    constraints: const BoxConstraints(minHeight: 115),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xffdce3ff),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        SvgPicture.asset(
                          'recurring_calendar_outline.svg',
                          package: 'assets',
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                recurrenceText(
                                  context,
                                  '약속을 생성할 때 날짜·시간 단계에서\n반복을 설정할 수 있습니다.',
                                  'Set repeat in the date and time step when creating an appointment.',
                                ),
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.35,
                                  color: Color(0xff4f69df),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                recurrenceText(
                                  context,
                                  '반복으로 등록하면 각 일정별 준비과정도\n함께 관리할 수 있습니다.',
                                  'Each repeated appointment can keep its own preparation.',
                                ),
                                style: const TextStyle(
                                  fontSize: 11,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const _RecurringSectionTitle(title: '등록된 반복 일정', count: 0),
                  const SizedBox(height: 7),
                  Container(
                    key: const Key('recurring_empty_card'),
                    constraints: const BoxConstraints(minHeight: 122),
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xfff6f6f6),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      recurrenceText(
                        context,
                        '아직 등록된 반복 일정이 없습니다.\n지금 약속을 추가하고 반복 일정을 관리해보세요.',
                        'No recurring schedules yet. Add an appointment to get started.',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.65,
                        color: Color(0xff545454),
                      ),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 47,
                    child: ElevatedButton(
                      key: const Key('recurring_empty_add'),
                      onPressed: onCreate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff4f69df),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        recurrenceText(context, '약속 추가', 'Add appointment'),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
    final next = widget.summary.next!;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .94,
        child: RecurrenceSheet(
          title: recurrenceText(context, '반복 종료', 'End series'),
          footer: ScreenActions(
            action: recurrenceText(context, '반복 종료', 'End series'),
            destructive: true,
            backLabel: recurrenceText(context, '취소', 'Cancel'),
            onBack: () => Navigator.pop(context, false),
            onAction: () => Navigator.pop(context, true),
          ),
          children: [
            const SizedBox(height: 16),
            Text(
              recurrenceText(
                context,
                '${recurrenceDay(context, next.scheduleTime)}부터 이후 회차의 반복을 종료할까요?',
                'End the series from ${recurrenceDay(context, next.scheduleTime)}?',
              ),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              recurrenceText(
                context,
                '아직 시작하지 않은 이후 회차는 모두 삭제됩니다. 이미 진행 중이거나 완료된 기록은 그대로 유지됩니다.',
                'Deletes upcoming occurrences. Active preparations and history are preserved.',
              ),
            ),
            RecurrencePanel(
              highlighted: true,
              child: Text(
                recurrenceText(
                  context,
                  '개별로 수정한 이후 회차도 삭제 대상에 포함됩니다.',
                  'Individually edited following occurrences are also deleted.',
                ),
              ),
            ),
            RecurrenceValue(
              label: recurrenceText(context, '종료되는 범위', 'Deleted occurrences'),
              value: recurrenceText(
                context,
                '다음 회차부터 이후의 모든 회차',
                'The next and all following occurrences',
              ),
            ),
            RecurrenceValue(
              label: recurrenceText(context, '계속 유지되는 항목', 'Preserved'),
              value: recurrenceText(
                context,
                '지난 기록과 현재 진행 중인 준비',
                'History and active preparations',
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
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
