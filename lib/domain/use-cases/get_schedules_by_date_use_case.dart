import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/error/failures.dart';
import 'package:on_time_front/core/error/result.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/repositories/schedule_repository.dart';

@Injectable()
class GetSchedulesByDateUseCase {
  final ScheduleRepository _scheduleRepository;

  GetSchedulesByDateUseCase(this._scheduleRepository);

  Stream<Result<List<ScheduleEntity>, Failure>> call(
      DateTime startDate, DateTime endDate) async* {
    final schedulesStream = _scheduleRepository.scheduleStream;
    await for (final result in schedulesStream) {
      if (result.isFailure) {
        yield Err(result.failureOrNull!);
        continue;
      }

      final schedules = result.successOrNull ?? const <ScheduleEntity>{};
      final filteredSchedules = schedules
          .where((schedule) =>
              schedule.scheduleTime.compareTo(startDate) >= 0 &&
              schedule.scheduleTime.isBefore(endDate))
          .toList()
        ..sort((a, b) => a.scheduleTime.compareTo(b.scheduleTime));

      yield Success(filteredSchedules);
    }
  }
}
