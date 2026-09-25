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

  /// Creates a profile only; an existing profile is never overwritten.
  Future<void> putUser(UserEntity userEntity) async {
    await into(db.users).insert(
      userEntity.toUserRow().toCompanion(false),
      mode: InsertMode.insertOrIgnore,
    );
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

  Future<User> _requireProfile(String userId) async {
    final row = await (select(
      users,
    )..where((u) => u.id.equals(userId))).getSingleOrNull();
    if (row == null) throw StateError('Local profile unavailable');
    return row;
  }

  Future<void> _writeProfile(String userId, UsersCompanion change) async {
    final updated = await (update(
      users,
    )..where((u) => u.id.equals(userId))).write(change);
    if (updated != 1) throw StateError('Local profile unavailable');
  }

  Future<void> markDurableDataChanged(String userId) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final updated = await customUpdate(
      '''
      UPDATE users
      SET data_revision = data_revision + 1,
          first_durable_data_at = COALESCE(first_durable_data_at, ?),
          last_durable_data_at = ?
      WHERE id = ?
      ''',
      variables: [
        Variable<int>(now),
        Variable<int>(now),
        Variable<String>(userId),
      ],
      updates: {users},
    );
    if (updated != 1) throw StateError('Local profile unavailable');
  }

  Future<void> updateSpareTime(String userId, Duration spareTime) =>
      transaction(() async {
        final current = await _requireProfile(userId);
        if (current.spareTime == spareTime.inMinutes) return;
        await _writeProfile(
          userId,
          UsersCompanion(spareTime: Value(spareTime.inMinutes)),
        );
        await markDurableDataChanged(userId);
      });

  /// The preparation write and this call share the repository's transaction.
  Future<void> completeOnboarding({
    required String userId,
    required Duration spareTime,
    required String note,
    required bool preparationChanged,
  }) => transaction(() async {
    final current = await _requireProfile(userId);
    final profileChanged =
        current.spareTime != spareTime.inMinutes ||
        current.note != note ||
        !current.isOnboardingCompleted;
    if (!profileChanged && !preparationChanged) return;
    if (profileChanged) {
      await _writeProfile(
        userId,
        UsersCompanion(
          spareTime: Value(spareTime.inMinutes),
          note: Value(note),
          isOnboardingCompleted: const Value(true),
        ),
      );
    }
    await markDurableDataChanged(userId);
  });

  /// Called inside the schedule outcome transaction; its revision is owned there.
  Future<void> incrementScore(String userId, {required bool onTime}) async {
    final updated = await customUpdate(
      '''
      UPDATE users SET eligible_outcome_count = eligible_outcome_count + 1,
          on_time_outcome_count = on_time_outcome_count + ? WHERE id = ?
      ''',
      variables: [Variable<int>(onTime ? 1 : 0), Variable<String>(userId)],
      updates: {users},
    );
    if (updated != 1) throw StateError('Local profile unavailable');
  }

  Future<void> updateAlarmSettings({
    required String userId,
    required bool enabled,
  }) => transaction(() async {
    final current = await _requireProfile(userId);
    if (current.alarmsEnabled == enabled) return;
    await _writeProfile(userId, UsersCompanion(alarmsEnabled: Value(enabled)));
    await markDurableDataChanged(userId);
  });

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
  }) => transaction(() async {
    final current = await _requireProfile(userId);
    if (current.detailedNotificationContent == enabled) return;
    await _writeProfile(
      userId,
      UsersCompanion(detailedNotificationContent: Value(enabled)),
    );
    await markDurableDataChanged(userId);
  });

  Future<void> resetScore(String userId) => transaction(() async {
    final current = await _requireProfile(userId);
    if (current.eligibleOutcomeCount == 0 && current.onTimeOutcomeCount == 0) {
      return;
    }
    await _writeProfile(
      userId,
      const UsersCompanion(
        eligibleOutcomeCount: Value(0),
        onTimeOutcomeCount: Value(0),
      ),
    );
    await markDurableDataChanged(userId);
  });

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
