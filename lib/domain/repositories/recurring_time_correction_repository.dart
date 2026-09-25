import '../entities/schedule_save.dart';
import '../recurrence/recurring_time_correction.dart';

abstract interface class RecurringTimeCorrectionRepository {
  Future<RecurringTimeCorrectionReview> review(
    RecurringTimeCorrectionRequest request,
  );
  Future<ScheduleSaveReceipt> confirm(RecurringTimeCorrectionCommand command);
  bool isCurrent(ScheduleSaveReceipt receipt);
}
