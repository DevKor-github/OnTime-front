import '../entities/schedule_save.dart';
import '../entities/schedule_time_correction.dart';
import '../entities/time_correction_conflict.dart';

abstract interface class ScheduleTimeCorrectionRepository {
  Future<ScheduleTimeCorrectionReview> review(String scheduleId);
  Future<TimeCorrectionConflictProof> reviewChoice(
    ScheduleTimeCorrectionCommand command,
  );
  Future<ScheduleSaveReceipt> confirm(ScheduleTimeCorrectionCommand command);
  bool isCurrent(ScheduleSaveReceipt receipt);
}
