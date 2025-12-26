import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/core/error/failures.dart';
import 'package:on_time_front/core/error/result.dart';
import 'package:on_time_front/core/error/unit.dart';

abstract interface class TimedPreparationRepository {
  Future<Result<Unit, Failure>> saveTimedPreparation(
    String scheduleId,
    PreparationWithTimeEntity preparation,
  );

  Future<Result<PreparationWithTimeEntity?, Failure>> getTimedPreparation(
    String scheduleId,
  );

  Future<Result<Unit, Failure>> clearTimedPreparation(String scheduleId);
}
