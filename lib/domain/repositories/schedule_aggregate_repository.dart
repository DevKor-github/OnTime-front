import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/schedule_save.dart';
import 'package:on_time_front/domain/use-cases/schedule_form_submission.dart';

abstract interface class ScheduleAggregateRepository {
  Future<ScheduleEditBaseline> newBaseline();
  Future<({ScheduleEditBaseline baseline, PreparationEntity preparation})>
  newDraft();
  Future<ScheduleEditSnapshot> readForEdit(String id);
  Future<ScheduleSaveReceipt> save(
    ScheduleFormSubmission submission, {
    required bool editing,
  });
  bool isCurrent(ScheduleSaveReceipt receipt);
}
