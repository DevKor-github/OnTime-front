import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/use-cases/get_nearest_upcoming_schedule_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_schedules_by_date_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_schedules_for_week_use_case.dart';

class StubGetSchedulesByDateUseCase implements GetSchedulesByDateUseCase {
  StubGetSchedulesByDateUseCase(this.handler);
  final Stream<List<ScheduleEntity>> Function(DateTime, DateTime) handler;

  @override
  Stream<List<ScheduleEntity>> call(DateTime startDate, DateTime endDate) {
    return handler(startDate, endDate);
  }
}

class StubLoadPreparationByScheduleIdUseCase
    implements LoadPreparationByScheduleIdUseCase {
  @override
  Future<void> call(String scheduleId) async {}
}

class StubGetPreparationByScheduleIdUseCase
    implements GetPreparationByScheduleIdUseCase {
  @override
  Future<PreparationEntity> call(String scheduleId) async {
    return const PreparationEntity(preparationStepList: []);
  }
}

class StubLoadSchedulesForWeekUseCase implements LoadSchedulesForWeekUseCase {
  StubLoadSchedulesForWeekUseCase(this.handler);
  final Future<void> Function(DateTime date) handler;

  @override
  Future<void> call(DateTime date) {
    return handler(date);
  }
}

void main() {
  test('swallows background week load failures before streaming cache',
      () async {
    final useCase = GetNearestUpcomingScheduleUseCase(
      StubGetSchedulesByDateUseCase(
        (_, __) => Stream.value(const <ScheduleEntity>[]),
      ),
      StubLoadPreparationByScheduleIdUseCase(),
      StubGetPreparationByScheduleIdUseCase(),
      StubLoadSchedulesForWeekUseCase(
        (_) async => throw Exception('unauthorized'),
      ),
    );

    await expectLater(useCase(), emitsInOrder([null, emitsDone]));
  });
}
