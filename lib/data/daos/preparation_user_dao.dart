import 'package:drift/drift.dart';
import 'package:on_time_front/data/mappers/domain_persistence_mappers.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import '/core/database/database.dart';
import 'package:on_time_front/data/tables/preparation_user_table.dart';
import 'package:on_time_front/data/tables/user_table.dart';

import 'package:on_time_front/domain/entities/preparation_entity.dart';

part 'preparation_user_dao.g.dart';

@DriftAccessor(tables: [PreparationUsers, Users])
class PreparationUserDao extends DatabaseAccessor<AppDatabase>
    with _$PreparationUserDaoMixin {
  final AppDatabase db;

  PreparationUserDao(this.db) : super(db);

  Future<void> createPreparationUser(
    PreparationEntity preparationEntity,
    String userId,
  ) async {
    String? previousStepId;

    for (var step in preparationEntity.preparationStepList) {
      final insertedStep = await into(
        db.preparationUsers,
      ).insertReturning(step.toPreparationUserRow(userId).toCompanion(false));

      if (previousStepId != null) {
        await (update(
          db.preparationUsers,
        )..where((tbl) => tbl.id.equals(previousStepId!))).write(
          PreparationUsersCompanion(nextPreparationId: Value(insertedStep.id)),
        );
      }

      previousStepId = insertedStep.id;
    }
  }

  Future<PreparationEntity> getPreparationUsersByUserId(String userId) async {
    final allSteps = await (select(
      db.preparationUsers,
    )..where((tbl) => tbl.userId.equals(userId))).get();

    if (allSteps.isEmpty) {
      return PreparationEntity(preparationStepList: []);
    }

    return PreparationEntity(
      preparationStepList: [
        for (final step in allSteps)
          PreparationStepEntity(
            id: step.id,
            preparationName: step.preparationName,
            preparationTime: Duration(minutes: step.preparationTime),
            nextPreparationId: step.nextPreparationId,
          ),
      ],
    ).ordered;
  }

  Future<PreparationStepEntity> getPreparationStepById(
    String preparationStepId,
  ) async {
    final result = await (select(
      db.preparationUsers,
    )..where((tbl) => tbl.id.equals(preparationStepId))).getSingleOrNull();

    if (result == null) {
      throw Exception("Preparation step not found");
    }

    return PreparationStepEntity(
      id: result.id,
      preparationName: result.preparationName,
      preparationTime: Duration(minutes: result.preparationTime),
      nextPreparationId: result.nextPreparationId,
    );
  }

  Future<void> updatePreparationUser(
    PreparationStepEntity stepEntity,
    String userId,
  ) async {
    await (update(
      db.preparationUsers,
    )..where((tbl) => tbl.id.equals(stepEntity.id))).write(
      PreparationUsersCompanion(
        preparationName: Value(stepEntity.preparationName),
        preparationTime: Value(stepEntity.preparationTime.inMinutes),
      ),
    );
  }

  Future<PreparationEntity> deletePreparationUser(String preparationId) async {
    final preparationToDelete = await (select(
      db.preparationUsers,
    )..where((tbl) => tbl.id.equals(preparationId))).getSingle();

    await (update(
      db.preparationUsers,
    )..where((tbl) => tbl.nextPreparationId.equals(preparationId))).write(
      PreparationUsersCompanion(
        nextPreparationId: Value(preparationToDelete.nextPreparationId),
      ),
    );

    await (delete(
      db.preparationUsers,
    )..where((tbl) => tbl.id.equals(preparationId))).go();

    return await getPreparationUsersByUserId(preparationToDelete.userId);
  }

  // Future<PreparationEntity> getPreparationUsersByUserIdAfterDeletion(
  //     String userId, String deletedId) async {
  //   final steps = await getPreparationUsersByUserId(userId);
  //   steps.preparationStepList.updateLinksAfterDeletion(deletedId);
  //   return steps;
  // }
}
