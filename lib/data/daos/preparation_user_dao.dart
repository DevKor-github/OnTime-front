import 'package:drift/drift.dart';
import '/core/database/database.dart';
import 'package:on_time_front/data/tables/preparation_user_table.dart';
import 'package:on_time_front/data/tables/user_table.dart';
import 'package:on_time_front/domain/entities/preparation_user_entity.dart';

part 'preparation_user_dao.g.dart';

@DriftAccessor(tables: [PreparationUsers, Users])
class PreparationUserDao extends DatabaseAccessor<AppDatabase>
    with _$PreparationUserDaoMixin {
  final AppDatabase db;

  PreparationUserDao(this.db) : super(db);

  Future<void> createPreparationUser(
      PreparationUserEntity preparationUserEntity) async {
    await into(db.preparationUsers).insert(
      preparationUserEntity.toModel().toCompanion(false),
    );
  }

  Future<List<PreparationUserEntity>> getPreparationUsersByUserId(
      int userId) async {
    final List<PreparationUser> query = await (select(db.preparationUsers)
          ..where((tbl) => tbl.userId.equals(userId)))
        .get();
    final List<PreparationUserEntity> preparationUserList = [];

    await Future.forEach(query, (preparationUser) async {
      final user = await (select(db.users)
            ..where((tbl) => tbl.id.equals(preparationUser.userId)))
          .getSingle();

      preparationUserList.add(
        PreparationUserEntity.fromModel(
          preparationUser as PreparationSchedule,
          user,
        ),
      );
    });

    return preparationUserList;
  }
}
