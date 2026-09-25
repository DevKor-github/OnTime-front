import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/schedule_save.dart';
import 'package:on_time_front/domain/use-cases/schedule_form_submission.dart';
import 'package:on_time_front/domain/use-cases/schedule_save_workflow.dart';

@Injectable()
class UpdateScheduleFormSubmissionUseCase {
  UpdateScheduleFormSubmissionUseCase(this.workflow);
  final ScheduleSaveWorkflow workflow;
  Future<ScheduleSaveReceipt> call(ScheduleFormSubmission submission) =>
      workflow.save(submission, editing: true);
  Future<ScheduleSaveReceipt> retryDelivery(ScheduleSaveReceipt receipt) =>
      workflow.retryDelivery(receipt);
}
