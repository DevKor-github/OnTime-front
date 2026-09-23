import 'package:injectable/injectable.dart';
import 'package:drift/drift.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';

abstract interface class PreparationLocalDataSource {
  Future<void> createDefaultPreparation(
    PreparationEntity preparationEntity, {
    required String userId,
  });

  Future<PreparationEntity> getDefaultPreparation(String userId);

  Future<void> createCustomPreparation(
    PreparationEntity preparationEntity,
    String scheduleId,
  );

  Future<void> replaceDefaultPreparation(
    PreparationEntity preparationEntity, {
    required String userId,
  });

  Future<void> replaceSchedulePreparation(
    PreparationEntity preparationEntity, {
    required String scheduleId,
  });

  Future<PreparationEntity> deletePreparation(
    PreparationEntity preparationEntity,
  );

  Future<PreparationEntity> getPreparationByScheduleId(String scheduleId);

  Future<PreparationStepEntity> getPreparationStepById(
    String preparationStepId,
  );
}

@Injectable(as: PreparationLocalDataSource)
class PreparationLocalDataSourceImpl implements PreparationLocalDataSource {
  final AppDatabase appDatabase;

  PreparationLocalDataSourceImpl({required this.appDatabase});

  @override
  Future<void> createDefaultPreparation(
    PreparationEntity preparationEntity, {
    required String userId,
  }) async {
    await appDatabase.preparationUserDao.createPreparationUser(
      preparationEntity,
      userId,
    );
  }

  @override
  Future<PreparationEntity> getDefaultPreparation(String userId) {
    return appDatabase.preparationUserDao.getPreparationUsersByUserId(userId);
  }

  @override
  Future<void> createCustomPreparation(
    PreparationEntity preparationEntity,
    String scheduleId,
  ) async {
    await appDatabase.preparationScheduleDao.createPreparationSchedule(
      preparationEntity,
      scheduleId,
    );
  }

  @override
  Future<PreparationEntity> getPreparationByScheduleId(
    String scheduleId,
  ) async {
    final schedule = await (appDatabase.select(
      appDatabase.schedules,
    )..where((t) => t.id.equals(scheduleId))).getSingleOrNull();
    if (schedule?.preparationDefinitionId != null) {
      return _definition(schedule!.preparationDefinitionId!);
    }
    return appDatabase.preparationScheduleDao
        .getPreparationSchedulesByScheduleId(scheduleId);
  }

  @override
  Future<PreparationStepEntity> getPreparationStepById(
    String preparationStepId,
  ) async {
    final row = await (appDatabase.select(
      appDatabase.preparationDefinitionSteps,
    )..where((t) => t.id.equals(preparationStepId))).getSingleOrNull();
    if (row != null) {
      final preparation = await _definition(row.definitionId);
      return preparation.preparationStepList.firstWhere(
        (s) => s.id == preparationStepId,
      );
    }
    return await appDatabase.preparationScheduleDao.getPreparationStepById(
      preparationStepId,
    );
  }

  Future<PreparationEntity> _definition(String id) async {
    final rows =
        await (appDatabase.select(appDatabase.preparationDefinitionSteps)
              ..where((t) => t.definitionId.equals(id))
              ..orderBy([(t) => OrderingTerm.asc(t.position)]))
            .get();
    return PreparationEntity(
      preparationStepList: [
        for (var i = 0; i < rows.length; i++)
          PreparationStepEntity(
            id: rows[i].id,
            preparationName: rows[i].name,
            preparationTime: Duration(minutes: rows[i].minutes),
            nextPreparationId: i + 1 < rows.length ? rows[i + 1].id : null,
          ),
      ],
    );
  }

  @override
  Future<PreparationEntity> deletePreparation(
    PreparationEntity preparationEntity,
  ) async {
    if (preparationEntity.preparationStepList.isEmpty) {
      throw Exception("No preparation steps to delete.");
    }

    final firstStep = preparationEntity.preparationStepList.first;

    if (firstStep.nextPreparationId != null) {
      // 스케줄 기반 삭제
      return await appDatabase.preparationScheduleDao.deletePreparationSchedule(
        firstStep.id,
      );
    } else {
      // 사용자 기반 삭제
      return await appDatabase.preparationUserDao.deletePreparationUser(
        firstStep.id,
      );
    }
  }

  @override
  Future<void> replaceDefaultPreparation(
    PreparationEntity preparationEntity, {
    required String userId,
  }) {
    return appDatabase.preparationUserDao.createPreparationUser(
      preparationEntity,
      userId,
    );
  }

  @override
  Future<void> replaceSchedulePreparation(
    PreparationEntity preparationEntity, {
    required String scheduleId,
  }) {
    return appDatabase.preparationScheduleDao.createPreparationSchedule(
      preparationEntity,
      scheduleId,
    );
  }
}
