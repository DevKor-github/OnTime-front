import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/use-cases/get_default_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_schedule_by_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_schedule_form_draft_use_case.dart';

class StubLoadPreparationByScheduleIdUseCase
    implements LoadPreparationByScheduleIdUseCase {
  @override
  Future<void> call(String scheduleId) async {}
}

class StubGetPreparationByScheduleIdUseCase
    implements GetPreparationByScheduleIdUseCase {
  @override
  Future<PreparationEntity> call(String scheduleId) {
    throw UnimplementedError();
  }
}

class StubGetDefaultPreparationUseCase implements GetDefaultPreparationUseCase {
  StubGetDefaultPreparationUseCase(this.preparation);

  final PreparationEntity preparation;

  @override
  Future<PreparationEntity> call() async => preparation;
}

class StubGetScheduleByIdUseCase implements GetScheduleByIdUseCase {
  @override
  call(String id) {
    throw UnimplementedError();
  }
}

void main() {
  test(
    'create draft uses default preparation, user spare time, generated ids, and seeded date',
    () async {
      final defaultPreparation = PreparationEntity(
        preparationStepList: const [
          PreparationStepEntity(
            id: 'prep-1',
            preparationName: 'Shower',
            preparationTime: Duration(minutes: 10),
          ),
        ],
      );
      final generatedIds = ['schedule-id', 'place-id'].iterator;
      String nextId() {
        generatedIds.moveNext();
        return generatedIds.current;
      }

      final useCase = LoadScheduleFormDraftUseCase.withOverrides(
        StubLoadPreparationByScheduleIdUseCase(),
        StubGetPreparationByScheduleIdUseCase(),
        StubGetDefaultPreparationUseCase(defaultPreparation),
        StubGetScheduleByIdUseCase(),
        now: () => DateTime(2027, 4, 5, 8, 30),
        newId: nextId,
      );

      final draft = await useCase.create(
        initialDate: DateTime(2027, 4, 5),
        currentUserSpareTime: const Duration(minutes: 5),
      );

      expect(draft.id, 'schedule-id');
      expect(draft.placeId, 'place-id');
      expect(draft.scheduleTime, DateTime(2027, 4, 5, 8, 31));
      expect(draft.scheduleSpareTime, const Duration(minutes: 5));
      expect(draft.preparation, defaultPreparation);
      expect(draft.preparationChanged, isFalse);
    },
  );
}
