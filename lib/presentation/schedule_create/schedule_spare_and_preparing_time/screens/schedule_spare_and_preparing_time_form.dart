import 'package:on_time_front/presentation/recurring/recurrence_components.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/presentation/recurring/recurrence_labels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/presentation/app/bloc/auth/auth_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/cubit/schedule_form_spare_time_cubit.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/cubit/preparation_edit_draft_cubit.dart';
import 'package:on_time_front/presentation/shared/components/cupertino_picker_modal.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/shared/utils/duration_format.dart';
import 'package:on_time_front/presentation/schedule_create/components/message_bubble.dart';

class ScheduleSpareAndPreparingTimeForm extends StatefulWidget {
  const ScheduleSpareAndPreparingTimeForm({super.key});

  @override
  State<ScheduleSpareAndPreparingTimeForm> createState() =>
      _ScheduleSpareAndPreparingTimeFormState();
}

class _ScheduleSpareAndPreparingTimeFormState
    extends State<ScheduleSpareAndPreparingTimeForm> {
  late DateTime date;
  late Duration spareTime;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ScheduleFormSpareTimeCubit, ScheduleFormSpareTimeState>(
      builder: (context, state) {
        if (context
                .read<ScheduleFormSpareTimeCubit>()
                .scheduleFormBloc
                .state
                .recurrenceRule !=
            null) {
          return _recurringPreparation(context, state);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (context
                    .read<ScheduleFormSpareTimeCubit>()
                    .scheduleFormBloc
                    .state
                    .recurrenceRule !=
                null)
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Text(
                  recurrenceText(
                    context,
                    '이 반복 일정의 준비과정이에요. 수정한 내용은 다른 반복 일정이나 기본 준비과정에 영향을 주지 않아요.',
                    'This preparation belongs to this series. Changes do not affect other series or your default preparation.',
                  ),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: FormField<Duration>(
                    initialValue: Duration.zero,
                    builder: (field) => TextField(
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(
                          context,
                        )!.preparationTimeTitle,
                      ),
                      controller: TextEditingController(
                        text: formatDuration(
                          context,
                          state.totalPreparationTime,
                        ),
                      ),
                      onTap: () {
                        final draftCubit = getIt
                            .get<PreparationEditDraftCubit>();
                        final scheduleSpareTimeCubit = context
                            .read<ScheduleFormSpareTimeCubit>();
                        final before =
                            state.preparation ??
                            const PreparationEntity(preparationStepList: []);

                        draftCubit.setDraft(before);
                        context.push('/preparationEdit').then((_) {
                          if (!mounted) return;

                          final after = draftCubit.state;
                          if (after != null && after != before) {
                            scheduleSpareTimeCubit.preparationChanged(after);
                          }

                          // Avoid stale drafts leaking into the next edit session.
                          draftCubit.clear();
                        });
                      },
                    ),
                    onSaved: (value) {},
                  ),
                ),
                SizedBox(width: 16),
                Builder(
                  builder: (context) {
                    final Duration spareTime =
                        state.spareTime.value ??
                        context.select(
                          (AuthBloc appBloc) =>
                              appBloc.state.user.spareTimeOrNull,
                        )!;
                    return Expanded(
                      flex: 1,
                      child: TextField(
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!.spareTime,
                        ),
                        controller: TextEditingController(
                          text: formatDurationAsMinutes(context, spareTime),
                        ),
                        onTap: () {
                          context.showCupertinoMinutePickerModal(
                            title: AppLocalizations.of(context)!.enterTime,
                            initialValue: spareTime,
                            onSaved: (value) {
                              context
                                  .read<ScheduleFormSpareTimeCubit>()
                                  .spareTimeChanged(value);
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
            if (state.hasOverlapMessage)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 16.0),
                child: MessageBubble(
                  message: state.getOverlapMessage(context)!,
                  type: state.isOverlapError
                      ? MessageBubbleType.error
                      : MessageBubbleType.warning,
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _editPreparation(ScheduleFormSpareTimeState state) async {
    final draft = getIt<PreparationEditDraftCubit>();
    final cubit = context.read<ScheduleFormSpareTimeCubit>();
    final before =
        state.preparation ?? const PreparationEntity(preparationStepList: []);
    draft.setDraft(before);
    await context.push('/preparationEdit');
    if (!mounted) return;
    final after = draft.state;
    if (after != null && after != before) cubit.preparationChanged(after);
    draft.clear();
  }

  Widget _recurringPreparation(
    BuildContext context,
    ScheduleFormSpareTimeState state,
  ) {
    final steps =
        state.preparation?.ordered.preparationStepList ??
        <PreparationStepEntity>[];
    return ListView(
      children: [
        Text(
          recurrenceText(
            context,
            '준비 과정을 확인하고\n필요한 항목을 수정하세요.',
            'Review your preparation\nand edit as needed.',
          ),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: 21,
            height: 30 / 21,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          recurrenceText(
            context,
            '이 약속의 반복에만 적용되는 준비 과정입니다.\n기본 준비과정의 복사본으로 생성되어\n이곳에서 수정해도 기존 설정에는 영향을 주지 않습니다.',
            'This preparation belongs only to this series. Changes do not affect your default preparation.',
          ),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: 13.5,
            height: 21 / 13.5,
            color: const Color(0xff545454),
          ),
        ),
        const SizedBox(height: 20),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: steps.length,
          onReorderItem: (oldIndex, newIndex) {
            final reordered = [...steps];
            reordered.insert(newIndex, reordered.removeAt(oldIndex));
            context.read<ScheduleFormSpareTimeCubit>().preparationChanged(
              PreparationEntity(
                preparationStepList: [
                  for (var i = 0; i < reordered.length; i++)
                    PreparationStepEntity(
                      id: reordered[i].id,
                      preparationName: reordered[i].preparationName,
                      preparationTime: reordered[i].preparationTime,
                      nextPreparationId: i + 1 < reordered.length
                          ? reordered[i + 1].id
                          : null,
                    ),
                ],
              ),
            );
          },
          itemBuilder: (context, i) => Padding(
            key: ValueKey(steps[i].id),
            padding: const EdgeInsets.only(bottom: 8),
            child: RecurrencePanel(
              padding: EdgeInsets.zero,
              child: ListTile(
                minTileHeight: 63,
                horizontalTitleGap: 24,
                leading: ReorderableDragStartListener(
                  index: i,
                  child: SvgPicture.asset(
                    'recurrence_preparation_drag.svg',
                    package: 'assets',
                  ),
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      steps[i].preparationName,
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 7),
                    ClipRect(
                      child: SizedBox(
                        width: double.infinity,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SvgPicture.asset(
                            'recurrence_preparation_underline.svg',
                            package: 'assets',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      child: Text(
                        formatDurationAsMinutes(
                          context,
                          steps[i].preparationTime,
                        ),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SvgPicture.asset(
                      'recurrence_preparation_chevron.svg',
                      package: 'assets',
                    ),
                  ],
                ),
                onTap: () => _editPreparation(state),
              ),
            ),
          ),
        ),
        if (steps.isEmpty)
          TextButton(
            onPressed: () => _editPreparation(state),
            child: Text(recurrenceText(context, '준비 과정 추가', 'Add preparation')),
          ),
        const SizedBox(height: 4),
        RecurrencePanel(
          padding: EdgeInsets.zero,
          child: ListTile(
            minTileHeight: 63,
            horizontalTitleGap: 24,
            leading: SvgPicture.asset(
              'recurrence_preparation_drag.svg',
              package: 'assets',
            ),
            title: Text(
              recurrenceText(
                context,
                '여유 (준비 합계 제외)',
                'Buffer (excluded from preparation total)',
              ),
              style: const TextStyle(fontSize: 18),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  child: Text(
                    formatDurationAsMinutes(
                      context,
                      state.spareTime.value ?? Duration.zero,
                    ),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(width: 12),
                SvgPicture.asset(
                  'recurrence_preparation_chevron.svg',
                  package: 'assets',
                ),
              ],
            ),
            onTap: () => context.showCupertinoMinutePickerModal(
              title: AppLocalizations.of(context)!.enterTime,
              initialValue: state.spareTime.value ?? Duration.zero,
              onSaved: (value) => context
                  .read<ScheduleFormSpareTimeCubit>()
                  .spareTimeChanged(value),
            ),
          ),
        ),
        const SizedBox(height: 16),
        RecurrencePanel(
          highlighted: true,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  recurrenceText(context, '총 준비 시간', 'Total preparation'),
                ),
              ),
              Text(
                formatDurationAsMinutes(context, state.totalPreparationTime),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
