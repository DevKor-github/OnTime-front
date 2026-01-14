import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/core/error/failures.dart';
import 'package:on_time_front/core/error/result.dart';
import 'package:on_time_front/core/error/unit.dart';

abstract interface class PreparationRepository {
  Stream<Result<Map<String, PreparationEntity>, Failure>> get preparationStream;

  Future<Result<Unit, Failure>> getPreparationByScheduleId(String scheduleId);

  Future<Result<PreparationEntity, Failure>> getDefualtPreparation();

  Future<Result<Unit, Failure>> createDefaultPreparation({
    required PreparationEntity preparationEntity,
    required Duration spareTime,
    required String note,
  });

  Future<Result<Unit, Failure>> createCustomPreparation(
    PreparationEntity preparationEntity,
    String scheduleId,
  );

  Future<Result<Unit, Failure>> updateDefaultPreparation(
    PreparationEntity preparationEntity,
  );

  Future<Result<Unit, Failure>> updatePreparationByScheduleId(
    PreparationEntity preparationEntity,
    String scheduleId,
  );

  Future<Result<Unit, Failure>> updateSpareTime(Duration newSpareTime);
}
