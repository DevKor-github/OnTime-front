import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/data/models/create_defualt_preparation_request_model.dart';
import 'package:on_time_front/data/models/create_preparation_schedule_request_model.dart';
import 'package:on_time_front/data/models/create_preparation_step_request_model.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';

void main() {
  const step = PreparationStepEntity(
    id: 'step-1',
    preparationName: 'Pack bag',
    preparationTime: Duration(minutes: 7),
    nextPreparationId: 'step-2',
  );

  test('schedule create model serializes and restores preparation steps', () {
    final model = PreparationScheduleCreateRequestModel.fromEntity(step);

    expect(model.toJson(), {
      'preparationId': 'step-1',
      'preparationName': 'Pack bag',
      'preparationTime': 7,
      'nextPreparationId': 'step-2',
    });
    expect(
      PreparationScheduleCreateRequestModel.fromJson(model.toJson()).toEntity(),
      step,
    );
  });

  test('schedule create list extension maps ordered steps', () {
    final models =
        PreparationScheduleCreateRequestModelListExtension.fromEntityList([
          step,
          const PreparationStepEntity(
            id: 'step-2',
            preparationName: 'Shoes',
            preparationTime: Duration(minutes: 3),
          ),
        ]);

    expect(models.map((model) => model.id), ['step-1', 'step-2']);
    expect(models.toEntityList().map((entity) => entity.nextPreparationId), [
      'step-2',
      null,
    ]);
  });

  test(
    'default preparation create model serializes backend request fields',
    () {
      final model = CreatePreparationStepRequestModel.fromEntity(step);

      expect(model.toJson(), {
        'preparationId': 'step-1',
        'preparationName': 'Pack bag',
        'preparationTime': 7,
        'nextPreparationId': 'step-2',
      });
      expect(
        CreatePreparationStepRequestModel.fromJson(model.toJson()).toEntity(),
        step,
      );
    },
  );

  test('default preparation request maps spare time note and step list', () {
    const preparation = PreparationEntity(preparationStepList: [step]);

    final model = CreateDefaultPreparationRequestModel.fromEntity(
      preparationEntity: preparation,
      spareTime: const Duration(minutes: 12),
      note: 'Bring umbrella',
    );

    expect(model.spareTime, 12);
    expect(model.note, 'Bring umbrella');
    expect(model.preparationList.single.id, 'step-1');
    expect(model.toJson()['spareTime'], 12);
  });
}
