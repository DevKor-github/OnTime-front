import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/use-cases/get_schedules_by_date_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_schedules_for_week_use_case.dart';
import 'package:on_time_front/presentation/home/bloc/weekly_schedules_bloc.dart';

class StubLoadSchedulesForWeekUseCase implements LoadSchedulesForWeekUseCase {
  StubLoadSchedulesForWeekUseCase(this.handler);
  final Future<void> Function(DateTime date) handler;

  @override
  Future<void> call(DateTime date) => handler(date);
}

class StubGetSchedulesByDateUseCase implements GetSchedulesByDateUseCase {
  @override
  Stream<List<ScheduleEntity>> call(DateTime startDate, DateTime endDate) {
    return const Stream.empty();
  }
}

void main() {
  test('load failure emits error state instead of throwing', () async {
    final bloc = WeeklySchedulesBloc(
      StubLoadSchedulesForWeekUseCase(
        (_) async => throw Exception('unauthorized'),
      ),
      StubGetSchedulesByDateUseCase(),
    );
    addTearDown(bloc.close);

    bloc.add(
      WeeklySchedulesSubscriptionRequested(date: DateTime(2026, 5, 5)),
    );

    await expectLater(
      bloc.stream,
      emitsThrough(
        isA<WeeklySchedulesState>().having(
          (state) => state.status,
          'status',
          WeeklySchedulesStatus.error,
        ),
      ),
    );
  });
}
