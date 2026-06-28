import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/preparation_step_with_time_entity.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/presentation/alarm/utils/preparation_step_state_mapper.dart';
import 'package:on_time_front/presentation/shared/constants/constants.dart';

void main() {
  group('PreparationStepStateMapper', () {
    const preparation = PreparationWithTimeEntity(
      preparationStepList: [
        PreparationStepWithTimeEntity(
          id: 's1',
          preparationName: 'wash',
          preparationTime: Duration(minutes: 10),
          nextPreparationId: 's2',
        ),
        PreparationStepWithTimeEntity(
          id: 's2',
          preparationName: 'dress',
          preparationTime: Duration(minutes: 10),
          nextPreparationId: null,
        ),
      ],
    );

    test('marks prior, current, and future preparation steps for display', () {
      final progressed = preparation.timeElapsed(const Duration(minutes: 12));

      expect(progressed.preparationStepStates, [
        PreparationStateEnum.done,
        PreparationStateEnum.now,
      ]);
    });

    test('marks every step done when preparation is complete', () {
      final completed = preparation.timeElapsed(const Duration(minutes: 20));

      expect(completed.preparationStepStates, [
        PreparationStateEnum.done,
        PreparationStateEnum.done,
      ]);
    });

    test('returns no display states for an empty preparation', () {
      const empty = PreparationWithTimeEntity(preparationStepList: []);

      expect(empty.preparationStepStates, isEmpty);
    });
  });
}
