import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/database/restore_runtime_identity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'unreadable store preserves original cause and cannot be labelled pending restore',
    () async {
      final original = StateError('synthetic key unavailable');
      final db = AppDatabase.forTesting(
        NativeDatabase.memory(setup: (_) => throw original),
      );
      addTearDown(db.close);
      final gate = LocalDataOperationGate();
      addTearDown(gate.dispose);
      var calls = 0;
      await expectLater(
        RestoreRuntimeIdentity().prepareStartup(
          db,
          gate,
          cleanupPlatform: () async {
            calls++;
          },
        ),
        throwsA(
          isA<RestoreStoreUnavailable>().having(
            (e) => e.cause,
            'original cause',
            same(original),
          ),
        ),
      );
      expect(calls, 0);
    },
  );
  test(
    'known committed marker classifies cleanup failure and preserves the receipt',
    () async {
      SharedPreferences.setMockInitialValues({});
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await db.userDao.putUser(
        const UserEntity(
          id: 'local-profile',
          spareTime: Duration.zero,
          note: 'keep',
        ),
      );
      await db.customStatement(
        'UPDATE users SET restore_cleanup_pending=1,reject_legacy_delivery=1',
      );
      final before = await db.select(db.users).getSingle();
      final gate = LocalDataOperationGate();
      addTearDown(gate.dispose);
      final original = StateError('OS unknown');
      await expectLater(
        RestoreRuntimeIdentity().prepareStartup(
          db,
          gate,
          cleanupPlatform: () async => throw original,
        ),
        throwsA(
          isA<RestoreRecoveryRequired>().having(
            (e) => e.cause,
            'cleanup cause',
            same(original),
          ),
        ),
      );
      expect(await db.select(db.users).getSingle(), before);
      expect(gate.isRecoveryPending, isTrue);
    },
  );
  for (final throwsWrite in [false, true]) {
    test(
      'runtime removal ${throwsWrite ? 'exception' : 'false receipt'} leaves durable pending until verified retry',
      () async {
        SharedPreferences.setMockInitialValues({});
        final store = _FailingStore(throwsWrite);
        SharedPreferencesStorePlatform.instance = store;
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        await db.userDao.putUser(
          const UserEntity(
            id: 'local-profile',
            spareTime: Duration.zero,
            note: 'keep',
          ),
        );
        await db.customStatement(
          'UPDATE users SET restore_cleanup_pending=1,reject_legacy_delivery=1',
        );
        final gate = LocalDataOperationGate();
        addTearDown(gate.dispose);
        final identity = RestoreRuntimeIdentity();
        var platformCalls = 0;
        await expectLater(
          identity.cleanup(
            db,
            gate,
            cleanupPlatform: () async {
              platformCalls++;
            },
          ),
          throwsStateError,
        );
        expect(
          (await db.select(db.users).getSingle()).restoreCleanupPending,
          isTrue,
        );
        expect(gate.isRecoveryPending, isTrue);
        expect(platformCalls, 0);
        expect(
          (await store.getAll()).containsKey(
            'flutter.early_start_session_same',
          ),
          isTrue,
        );
        store.fail = false;
        // A failed legacy remove changes its in-memory cache before persistence;
        // reload represents the next retry/restart's authoritative prefs read.
        await (await SharedPreferences.getInstance()).reload();
        await identity.cleanup(
          db,
          gate,
          cleanupPlatform: () async {
            platformCalls++;
          },
        );
        expect(
          (await db.select(db.users).getSingle()).restoreCleanupPending,
          isFalse,
        );
        expect(platformCalls, 1);
        expect(
          (await store.getAll()).containsKey(
            'flutter.early_start_session_same',
          ),
          isFalse,
        );
        SharedPreferences.setMockInitialValues({});
      },
    );
  }
}

class _FailingStore extends InMemorySharedPreferencesStore {
  _FailingStore(this.throwsWrite)
    : super.withData({
        'flutter.early_start_session_same': 'old',
        'flutter.unrelated': 'keep',
      });
  final bool throwsWrite;
  bool fail = true;
  @override
  Future<bool> remove(String key) async {
    if (fail) {
      if (throwsWrite) throw StateError('injected prefs write');
      return false;
    }
    return super.remove(key);
  }
}
