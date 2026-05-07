import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/data/models/get_preparation_step_response_model.dart';

void main() {
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

      expect(
        preparation.preparationStepList.map((step) => step.id),
        ['first', 'second', 'third'],
      );
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

      expect(
        preparation.preparationStepList.map((step) => step.id),
        ['first', 'second', 'unlinked'],
      );
    });
  });
}
