import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/schedule_save.dart';
import 'package:on_time_front/domain/use-cases/update_schedule_form_submission_use_case.dart';
import 'package:on_time_front/domain/use-cases/schedule_save_workflow.dart';
import 'package:on_time_front/domain/use-cases/schedule_form_submission.dart';
import '../../data/repositories/schedule_aggregate_repository_test.dart'
    show schedule, prep;

class Workflow extends Fake implements ScheduleSaveWorkflow {
  bool? editing;
  int saves = 0;
  int retries = 0;
  @override
  Future<ScheduleSaveReceipt> save(
    ScheduleFormSubmission value, {
    required bool editing,
  }) async {
    this.editing = editing;
    saves++;
    return ScheduleSaveReceipt(
      scheduleId: value.schedule.id,
      mutationId: 'intent',
      generation: 0,
      changed: true,
      deliveryPending: true,
    );
  }

  @override
  Future<ScheduleSaveReceipt> retryDelivery(ScheduleSaveReceipt receipt) async {
    retries++;
    return receipt.withDeliveryPending(false);
  }
}

void main() {
  test('update preserves committed result and retries delivery only', () async {
    final workflow = Workflow();
    final useCase = UpdateScheduleFormSubmissionUseCase(workflow);
    final receipt = await useCase(
      ScheduleFormSubmission(
        schedule: schedule(),
        preparation: prep(),
        preparationChanged: true,
      ),
    );
    expect(workflow.editing, true);
    expect(receipt.deliveryPending, isTrue);
    expect((await useCase.retryDelivery(receipt)).deliveryPending, isFalse);
    expect(workflow.saves, 1);
    expect(workflow.retries, 1);
  });
}
