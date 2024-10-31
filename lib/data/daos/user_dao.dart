import 'package:drift/drift.dart';
import 'package:on_time_front/config/database.dart';
import 'package:on_time_front/data/tables/user_table.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';

part 'user_dao.g.dart';

@DriftAccessor(tables: [Users])
class UserDao extends DatabaseAccessor<AppDatabase> with _$UserDaoMixin {
  final AppDatabase db;

  UserDao(this.db) : super(db);

  Future<void> createUser(UserEntity userEntity) async {
    await into(db.users).insert(
      userEntity.toModel().toCompanion(false),
    );
  }

  Future<UserEntity?> getUserById(int userId) async {
    final user = await (select(db.users)..where((tbl) => tbl.id.equals(userId)))
        .getSingleOrNull();
    if (user != null) {
      return UserEntity.fromModel(user);
    }
    return null;
  }

  Future<List<UserEntity>> getAllUsers() async {
    final query = await select(db.users).get();
    return query.map((user) => UserEntity.fromModel(user)).toList();
  }
}
