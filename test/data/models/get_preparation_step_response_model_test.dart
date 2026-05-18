import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/data/models/get_preparation_step_response_model.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';

void main() {
  test('maps preparation step JSON and entity durations in minutes', () {
    final model = GetPreparationStepResponseModel.fromJson({
      'preparationId': 'prep-1',
      'preparationName': 'Shower',
      'preparationTime': 12,
      'nextPreparationId': 'prep-2',
    });

    expect(model.id, 'prep-1');
    expect(model.toJson(), {
      'preparationId': 'prep-1',
      'preparationName': 'Shower',
      'preparationTime': 12,
      'nextPreparationId': 'prep-2',
    });

    final entity = model.toEntity();
    expect(entity.preparationTime, const Duration(minutes: 12));

    final fromEntity = GetPreparationStepResponseModel.fromEntity(
      const PreparationStepEntity(
        id: 'prep-3',
        preparationName: 'Pack bag',
        preparationTime: Duration(minutes: 7),
        nextPreparationId: null,
      ),
    );
    expect(fromEntity.id, 'prep-3');
    expect(fromEntity.preparationTime, 7);
    expect(fromEntity.nextPreparationId, isNull);
  });

  group('PreparationResponseModelListExtension', () {
    test('orders preparation steps by nextPreparationId chain', () {
      final models = [
        GetPreparationStepResponseModel(
          id: 'third',
          preparationName: 'Put on shoes',
          preparationTime: 3,
          nextPreparationId: null,
        ),
        GetPreparationStepResponseModel(
          id: 'first',
          preparationName: 'Shower',
          preparationTime: 10,
          nextPreparationId: 'second',
        ),
        GetPreparationStepResponseModel(
          id: 'second',
          preparationName: 'Get dressed',
          preparationTime: 5,
          nextPreparationId: 'third',
        ),
      ];

      final preparation = models.toPreparationEntity();

      expect(preparation.preparationStepList.map((step) => step.id), [
        'first',
        'second',
        'third',
      ]);
    });

    test('keeps unlinked steps instead of dropping them', () {
      final models = [
        GetPreparationStepResponseModel(
          id: 'first',
          preparationName: 'Shower',
          preparationTime: 10,
          nextPreparationId: 'second',
        ),
        GetPreparationStepResponseModel(
          id: 'second',
          preparationName: 'Get dressed',
          preparationTime: 5,
          nextPreparationId: null,
        ),
        GetPreparationStepResponseModel(
          id: 'unlinked',
          preparationName: 'Pack bag',
          preparationTime: 2,
          nextPreparationId: null,
        ),
      ];

      final preparation = models.toPreparationEntity();

      expect(preparation.preparationStepList.map((step) => step.id), [
        'first',
        'second',
        'unlinked',
      ]);
    });
  });
}
