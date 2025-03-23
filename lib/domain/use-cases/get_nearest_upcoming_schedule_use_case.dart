import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:on_time_front/data/tables/schedule_with_place_model.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/repositories/schedule_repository.dart';
import 'package:on_time_front/domain/use-cases/get_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_schedules_by_date_use_case.dart';

@Injectable()
class GetNearestUpcomingScheduleUseCase {
  final GetSchedulesByDateUseCase _getScheduleByDateUseCase;
  final GetPreparationByScheduleIdUseCase _getPreparationByScheduleIdUseCase;

  GetNearestUpcomingScheduleUseCase(
      this._getScheduleByDateUseCase, this._getPreparationByScheduleIdUseCase);

  Stream<ScheduleWithPreparationEntity?> call() {
    final DateTime now = DateTime.now();
    final StreamController<ScheduleWithPreparationEntity?> controller =
        StreamController<ScheduleWithPreparationEntity?>();

    _getScheduleByDateUseCase(now, now.add(const Duration(days: 2)))
        .listen((schedules) async {
      if (schedules.isNotEmpty) {
        final preparation =
            await _getPreparationByScheduleIdUseCase(schedules.first.id);
        final scheduleWithPreparation =
            ScheduleWithPreparationEntity.fromScheduleAndPreparationEntity(
                schedules.first, preparation);
        controller.add(scheduleWithPreparation);
      } else {
        controller.add(null);
      }
    });

    return controller.stream;
  }
}
