import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import '/core/database/database.dart';

import 'package:on_time_front/data/tables/preparation_schedule_table.dart';
import 'package:on_time_front/data/tables/schedules_table.dart';
import 'package:on_time_front/data/tables/user_table.dart';
import 'package:on_time_front/data/tables/places_table.dart';

import 'package:on_time_front/domain/entities/preparation_entity.dart';

part 'preparation_schedule_dao.g.dart';

@DriftAccessor(tables: [PreparationSchedules, Schedules, Users, Places])
class PreparationScheduleDao extends DatabaseAccessor<AppDatabase>
    with _$PreparationScheduleDaoMixin {
  final AppDatabase db;

  PreparationScheduleDao(this.db) : super(db);

  Future<void> createPreparationSchedule(
      PreparationEntity preparationEntity, String scheduleId) async {
    String? previousStepId;

    for (var step in preparationEntity.preparationStepList) {
      // Step 1: Insert the current preparation step
      final insertedStep = await into(db.preparationSchedules).insertReturning(
        step.toPreparationScheduleModel(scheduleId).toCompanion(false),
      );

      // Step 2: Update the `nextPreparationId` of the previous step
      if (previousStepId != null) {
        await (update(db.preparationSchedules)
              ..where((tbl) => tbl.id.equals(previousStepId!)))
            .write(
          PreparationSchedulesCompanion(
              nextPreparationId: Value(insertedStep.id)),
        );
      }

      // Step 3: Set the current step's ID as the previous step ID for the next iteration
      previousStepId = insertedStep.id;
    }
  }

  Future<PreparationEntity> getPreparationSchedulesByScheduleId(
      String scheduleId) async {
    final allSteps = await (select(db.preparationSchedules)
          ..where((tbl) => tbl.scheduleId.equals(scheduleId)))
        .get();

    if (allSteps.isEmpty) {
      return PreparationEntity(preparationStepList: []);
    }

    final firstStep = allSteps.firstWhere(
      (step) => allSteps.every((other) => other.nextPreparationId != step.id),
      orElse: () => allSteps.first,
    );

    final List<PreparationStepEntity> orderedSteps = [];
    PreparationSchedule? currentStep = firstStep;

    while (currentStep != null) {
      orderedSteps.add(
        PreparationStepEntity(
          id: currentStep.id,
          preparationName: currentStep.preparationName,
          preparationTime: currentStep.preparationTime,
          nextPreparationId: currentStep.nextPreparationId,
        ),
      );
      currentStep = allSteps.firstWhereOrNull(
        (step) => step.id == currentStep!.nextPreparationId,
      );
    }

    return PreparationEntity(preparationStepList: orderedSteps);
  }

  Future<PreparationStepEntity> getPreparationStepById(
      String preparationStepId) async {
    final result = await (select(db.preparationSchedules)
          ..where((tbl) => tbl.id.equals(preparationStepId)))
        .getSingleOrNull();

    if (result == null) {
      throw Exception("Preparation step not found");
    }

    return PreparationStepEntity(
      id: result.id,
      preparationName: result.preparationName,
      preparationTime: result.preparationTime,
      nextPreparationId: result.nextPreparationId,
    );
  }

  Future<void> updatePreparationSchedule(
      PreparationStepEntity stepEntity, String scheduleId) async {
    await (update(db.preparationSchedules)
          ..where((tbl) => tbl.id.equals(stepEntity.id)))
        .write(
      PreparationSchedulesCompanion(
        preparationName: Value(stepEntity.preparationName),
        preparationTime: Value(stepEntity.preparationTime),
        nextPreparationId: Value(stepEntity.nextPreparationId),
      ),
    );
  }

  Future<PreparationEntity> deletePreparationSchedule(
      String preparationId) async {
    // Step 1: 삭제할 준비 과정을 가져오기
    final preparationToDelete = await (select(db.preparationSchedules)
          ..where((tbl) => tbl.id.equals(preparationId)))
        .getSingle();

    // Step 2: 이전 노드의 nextPreparationId를 업데이트
    await (update(db.preparationSchedules)
          ..where((tbl) => tbl.nextPreparationId.equals(preparationId)))
        .write(
      PreparationSchedulesCompanion(
        nextPreparationId: Value(preparationToDelete.nextPreparationId),
      ),
    );

    // Step 3: 해당 노드 삭제
    await (delete(db.preparationSchedules)
          ..where((tbl) => tbl.id.equals(preparationId)))
        .go();

    // Step 4: 재정렬된 PreparationEntity 반환
    return await getPreparationSchedulesByScheduleId(
        preparationToDelete.scheduleId);
  }
}
