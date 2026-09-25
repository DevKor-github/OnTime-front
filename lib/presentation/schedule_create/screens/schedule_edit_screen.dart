import 'package:on_time_front/domain/recurrence/recurring_schedule.dart';
import 'package:on_time_front/core/time/schedule_time_resolution.dart';
import 'package:on_time_front/domain/use-cases/schedule_time_correction_workflow.dart';
import 'schedule_time_correction_screen.dart';
import 'package:on_time_front/domain/use-cases/recurring_time_correction_workflow.dart';
import 'package:on_time_front/presentation/recurring/recurring_time_correction_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/schedule_form_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/components/keyboard_backed_bottom_sheet.dart';
import 'package:on_time_front/presentation/schedule_create/components/schedule_multi_page_form.dart';

class ScheduleEditScreen extends StatelessWidget {
  const ScheduleEditScreen({
    super.key,
    required this.scheduleId,
    this.scope = RecurringEditScope.occurrence,
  });

  final String scheduleId;
  final RecurringEditScope scope;

  @override
  Widget build(BuildContext context) {
    return KeyboardBackedBottomSheet(
      child: BlocProvider<ScheduleFormBloc>(
        create: (context) => getIt.get<ScheduleFormBloc>()
          ..add(
            ScheduleFormEditRequested(scheduleId: scheduleId, scope: scope),
          ),
        child: BlocBuilder<ScheduleFormBloc, ScheduleFormState>(
          builder: (context, state) {
            final original = state.originalSchedule;
            if (state.status == ScheduleFormStatus.success &&
                original != null &&
                ScheduleTimeResolver.resolve(
                      original,
                      nowUtc: DateTime.now().toUtc(),
                    ).instantUtc ==
                    null) {
              if (scope == RecurringEditScope.following &&
                  original.isRecurring) {
                return Material(
                  type: MaterialType.transparency,
                  child: RecurringTimeCorrectionScreen(
                    key: ValueKey((original.id, state.mutationId)),
                    scheduleId: original.id,
                    workflow: getIt.get<RecurringTimeCorrectionWorkflow>(),
                    individualWorkflow: getIt
                        .get<ScheduleTimeCorrectionWorkflow>(),
                  ),
                );
              }
              return Material(
                type: MaterialType.transparency,
                child: ScheduleTimeCorrectionScreen(
                  key: ValueKey((original.id, state.mutationId)),
                  scheduleId: original.id,
                  workflow: getIt.get<ScheduleTimeCorrectionWorkflow>(),
                ),
              );
            }
            return ScheduleMultiPageForm(
              onSaved: () => context.read<ScheduleFormBloc>().add(
                const ScheduleFormUpdated(),
              ),
            );
          },
        ),
      ),
    );
  }
}
