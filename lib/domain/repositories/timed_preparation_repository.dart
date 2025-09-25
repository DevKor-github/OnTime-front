import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';

abstract interface class TimedPreparationRepository {
  Future<void> saveTimedPreparation(
      String scheduleId, PreparationWithTimeEntity preparation);

  Future<PreparationWithTimeEntity?> getTimedPreparation(String scheduleId);

  Future<void> clearTimedPreparation(String scheduleId);
}
