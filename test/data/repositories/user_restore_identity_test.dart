import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:on_time_front/data/data_sources/early_start_session_local_data_source.dart';
import '../../domain/use-cases/alarm_reconciliation_concurrency_test.dart'
    as concurrency;
import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/database/restore_runtime_identity.dart';
import 'package:on_time_front/data/daos/user_dao.dart';
import 'package:on_time_front/data/repositories/user_repository_impl.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'first profile creation publishes its actual durable identity',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final identity = RestoreRuntimeIdentity.shared;
      await identity.load(db);
      expect(identity.storeIncarnation, isNull);
      final repository = UserRepositoryImpl(db);
      addTearDown(repository.dispose);
      await repository.getUser();
      expect(
        identity.storeIncarnation,
        (await db.select(db.users).getSingle()).storeIncarnation,
      );
      expect(identity.storeIncarnation, isNotNull);
      SharedPreferences.setMockInitialValues({});
      await EarlyStartSessionLocalDataSourceImpl().saveSession(
        scheduleId: 'first',
        startedAt: DateTime.utc(2030),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        jsonDecode(
          prefs.getString('early_start_session_first')!,
        )['storeIncarnation'],
        identity.storeIncarnation,
      );
      final rig = concurrency.Rig();
      addTearDown(rig.dispose);
      rig.repository.schedules = [rig.schedule('first')];
      await rig.reconcile();
      expect(
        rig.registry.records.single.payload['storeIncarnation'],
        identity.storeIncarnation,
      );
    },
  );
  test(
    'late existing profile read cannot emit old row after replacement',
    () async {
      final db = _BlockingDb();
      addTearDown(db.close);
      await db.userDao.putUser(
        const UserEntity(
          id: 'local-profile',
          spareTime: Duration.zero,
          note: 'old',
        ),
      );
      final repository = UserRepositoryImpl(db);
      addTearDown(repository.dispose);
      final seen = <String>[];
      final subscription = repository.userStream.listen((u) {
        if (u.valueOrNull != null) seen.add(u.valueOrNull!.note);
      });
      addTearDown(subscription.cancel);
      db.block = true;
      final pending = repository.getUser();
      final rejected = expectLater(
        pending,
        throwsA(isA<LocalDataUnavailable>()),
      );
      await db.entered.future;
      await LocalDataOperationGate.shared.run(() async {
        await db.deleteAllDurableData();
        await db.userDao.putUser(
          const UserEntity(
            id: 'local-profile',
            spareTime: Duration.zero,
            note: 'new',
          ),
        );
      }, replacesData: true);
      await pumpEventQueue();
      seen.clear();
      db.release.complete();
      await rejected;
      await pumpEventQueue();
      expect(seen, isNot(contains('old')));
      expect((await db.select(db.users).getSingle()).note, 'new');
    },
  );
}

class _BlockingDb extends AppDatabase {
  _BlockingDb() : super.forTesting(NativeDatabase.memory());
  bool block = false;
  final entered = Completer<void>(), release = Completer<void>();
  late final UserDao _blockingDao = _BlockingDao(this);
  @override
  UserDao get userDao => _blockingDao;
}

class _BlockingDao extends UserDao {
  _BlockingDao(this.owner) : super(owner);
  final _BlockingDb owner;
  @override
  Future<UserEntity?> getUserById(String id) async {
    final value = await super.getUserById(id);
    if (owner.block) {
      owner.entered.complete();
      await owner.release.future;
    }
    return value;
  }
}
