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

  Future<void> putUser(UserEntity userEntity) async {
    await into(
      db.users,
    ).insertOnConflictUpdate(userEntity.toUserRow().toCompanion(false));
  }

  Future<void> createUser(UserEntity userEntity) => putUser(userEntity);

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

  Stream<UserEntity?> watchUserById(String userId) {
    return (select(db.users)..where((table) => table.id.equals(userId)))
        .watchSingleOrNull()
        .map((row) => row?.toUserEntity());
  }

  Future<void> markDurableDataChanged(String userId) async {
    final now = DateTime.now();
    await customStatement(
      '''
      UPDATE users
      SET data_revision = data_revision + 1,
          first_durable_data_at = COALESCE(first_durable_data_at, ?),
          last_durable_data_at = ?
      WHERE id = ?
      ''',
      [
        now.millisecondsSinceEpoch ~/ 1000,
        now.millisecondsSinceEpoch ~/ 1000,
        userId,
      ],
    );
  }

  Future<void> updateAlarmSettings({
    required String userId,
    required bool enabled,
  }) async {
    await (update(users)..where((table) => table.id.equals(userId))).write(
      UsersCompanion(alarmsEnabled: Value(enabled)),
    );
    await markDurableDataChanged(userId);
  }

  Future<({bool enabled, int offsetMinutes, bool detailedNotificationContent})>
  getAlarmSettings(String userId) async {
    final row = await (select(
      users,
    )..where((table) => table.id.equals(userId))).getSingleOrNull();
    return (
      enabled: row?.alarmsEnabled ?? true,
      offsetMinutes: row?.alarmOffsetMinutes ?? 0,
      detailedNotificationContent: row?.detailedNotificationContent ?? false,
    );
  }

  Future<void> updateDetailedNotificationContent({
    required String userId,
    required bool enabled,
  }) async {
    await (update(users)..where((table) => table.id.equals(userId))).write(
      UsersCompanion(detailedNotificationContent: Value(enabled)),
    );
    await markDurableDataChanged(userId);
  }

  Future<void> resetScore(String userId) async {
    await (update(users)..where((table) => table.id.equals(userId))).write(
      const UsersCompanion(
        eligibleOutcomeCount: Value(0),
        onTimeOutcomeCount: Value(0),
      ),
    );
    await markDurableDataChanged(userId);
  }

  Future<void> markExported({
    required String userId,
    required int revision,
    required DateTime cutoff,
  }) async {
    final updated =
        await (update(users)..where((table) => table.id.equals(userId))).write(
          UsersCompanion(
            lastExportedRevision: Value(revision),
            lastExportedAt: Value(cutoff),
          ),
        );
    if (updated != 1) throw StateError('Local profile unavailable');
  }
}
