import 'package:drift/drift.dart';
import '/core/database/database.dart';
import 'package:on_time_front/data/mappers/domain_persistence_mappers.dart';
import 'package:on_time_front/data/tables/user_table.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';

part 'user_dao.g.dart';

@DriftAccessor(tables: [Users])
class UserDao extends DatabaseAccessor<AppDatabase> with _$UserDaoMixin {
  final AppDatabase db;

  UserDao(this.db) : super(db);

  Future<void> createUser(UserEntity userEntity) async {
    await into(db.users).insert(userEntity.toUserRow().toCompanion(false));
  }

  Future<UserEntity?> getUserById(String userId) async {
    final user = await (select(
      db.users,
    )..where((tbl) => tbl.id.equals(userId))).getSingleOrNull();
    if (user != null) {
      return user.toUserEntity();
    }
    return null;
  }

  Future<List<UserEntity>> getAllUsers() async {
    final query = await select(db.users).get();
    return query.map((user) => user.toUserEntity()).toList();
  }
}
