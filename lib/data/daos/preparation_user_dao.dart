import 'package:drift/drift.dart';
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
      PreparationEntity preparationEntity, int userId) async {
    for (var step in preparationEntity.preparationStepList) {
      await into(db.preparationUsers).insert(
        step.toPreparationUserModel(userId).toCompanion(false),
      );
    }
  }

  Future<List<PreparationEntity>> getPreparationUsersByUserId(
      int userId) async {
    final List<PreparationUser> query = await (select(db.preparationUsers)
          ..where((tbl) => tbl.userId.equals(userId)))
        .get();
    final List<PreparationStepEntity> stepEntities = [];

    for (var preparationUser in query) {
      stepEntities.add(
        PreparationStepEntity(
          id: preparationUser.id,
          preparationName: preparationUser.preparationName,
          preparationTime: preparationUser.preparationTime,
          order: preparationUser.order,
        ),
      );
    }

    // await Future.forEach(
    //   query,
    //   (preparationUser) async {
    //     final user = await (select(db.users)
    //           ..where((tbl) => tbl.id.equals(preparationUser.userId)))
    //         .getSingle();

    //     preparationUserList.add(
    //       PreparationEntity.fromModel(
    //         preparationUser as PreparationSchedule,
    //         user,
    //       ),
    //     );
    //   },
    // );

    return [PreparationEntity(preparationStepList: stepEntities)];
  }
}
