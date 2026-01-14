import 'package:flutter/material.dart';
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
  const ScheduleSpareAndPreparingTimeForm({
    super.key,
  });

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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                        labelText:
                            AppLocalizations.of(context)!.preparationTimeTitle),
                    controller: TextEditingController(
                        text: formatDuration(
                            context, state.totalPreparationTime)),
                    onTap: () {
                      final draftCubit = getIt.get<PreparationEditDraftCubit>();
                      final scheduleSpareTimeCubit =
                          context.read<ScheduleFormSpareTimeCubit>();
                      final before = state.preparation ??
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
              SizedBox(
                width: 16,
              ),
              Builder(
                builder: (context) {
                  final Duration spareTime = state.spareTime.value ??
                      context.select((AuthBloc appBloc) => appBloc.state.user
                          .mapOrNull((user) => user.spareTime))!;
                  return Expanded(
                    flex: 1,
                    child: TextField(
                      readOnly: true,
                      decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!.spareTime),
                      controller: TextEditingController(
                          text: formatDuration(context, spareTime)),
                      onTap: () {
                        context.showCupertinoMinutePickerModal(
                            title: AppLocalizations.of(context)!.enterTime,
                            initialValue: spareTime,
                            onSaved: (value) {
                              context
                                  .read<ScheduleFormSpareTimeCubit>()
                                  .spareTimeChanged(value);
                            });
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
    });
  }
}
