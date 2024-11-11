import 'package:drift/drift.dart';
import '/core/database/database.dart';
import 'package:on_time_front/data/tables/preparation_user_table.dart';

part 'preparation_user_dao.g.dart';

@DriftAccessor(tables: [PreparationUsers])
class PreparationUserDao extends DatabaseAccessor<AppDatabase>
    with _$PreparationUserDaoMixin {
  final AppDatabase db;

  PreparationUserDao(this.db) : super(db);

  Future<List<PreparationUser>> createPreparationUser(
      List<PreparationUser> preparationUserModel, String userId) async {
    final List<PreparationUser> preparationUserList = [];
    for (var step in preparationUserModel) {
      preparationUserList.add(await into(db.preparationUsers).insertReturning(
        step.toCompanion(false),
      ));
    }
    return preparationUserList;
  }

  Future<List<PreparationUser>> getPreparationUsersByUserId(
      String userId) async {
    final List<PreparationUser> query = await (select(db.preparationUsers)
          ..where((tbl) => tbl.userId.equals(userId)))
        .get();
    return query;
  }

  Future<void> deletePreparationUserByUserId(String userId) async {
    await (delete(db.preparationUsers)
          ..where((tbl) => tbl.userId.equals(userId)))
        .go();
  }
}
