import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/data/models/update_preparation_schedule_request_model.dart';
import 'package:on_time_front/data/models/update_preparation_user_request_model.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';

void main() {
  const step = PreparationStepEntity(
    id: 'step-1',
    preparationName: 'Shower',
    preparationTime: Duration(minutes: 15),
    nextPreparationId: 'step-2',
  );

  test('schedule modify model round-trips preparation steps', () {
    final model = PreparationScheduleModifyRequestModel.fromEntity(step);

    expect(model.id, 'step-1');
    expect(model.preparationName, 'Shower');
    expect(model.preparationTime, 15);
    expect(model.nextPreparationId, 'step-2');
    expect(model.toJson(), {
      'preparationId': 'step-1',
      'preparationName': 'Shower',
      'preparationTime': 15,
      'nextPreparationId': 'step-2',
    });
    expect(model.toEntity(), step);
  });

  test('schedule modify list extension maps every step', () {
    final models =
        PreparationScheduleModifyRequestModelListExtension.fromEntityList([
          step,
          step.copyWith(id: 'step-2', nextPreparationId: null),
        ]);

    expect(models.map((model) => model.id), ['step-1', 'step-2']);
    expect(models.toEntityList().map((entity) => entity.id), [
      'step-1',
      'step-2',
    ]);
  });

  test('user modify model round-trips preparation steps', () {
    final model = PreparationUserModifyRequestModel.fromEntity(step);

    expect(model.id, 'step-1');
    expect(model.preparationName, 'Shower');
    expect(model.preparationTime, 15);
    expect(model.nextPreparationId, 'step-2');
    expect(model.toJson(), {
      'preparationId': 'step-1',
      'preparationName': 'Shower',
      'preparationTime': 15,
      'nextPreparationId': 'step-2',
    });
    expect(model.toEntity(), step);
  });

  test('user modify list extension maps every step', () {
    final models =
        PreparationUserModifyRequestModelListExtension.fromEntityList([
          step,
          step.copyWith(id: 'step-2', nextPreparationId: null),
        ]);

    expect(models.map((model) => model.id), ['step-1', 'step-2']);
    expect(models.toEntityList().map((entity) => entity.id), [
      'step-1',
      'step-2',
    ]);
  });
}
