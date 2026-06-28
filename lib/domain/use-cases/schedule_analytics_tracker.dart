import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';

abstract interface class ScheduleAnalyticsTracker {
  Future<void> trackScheduleCreated({
    required ScheduleEntity schedule,
    required PreparationEntity preparation,
  });
}
