import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';

void main() {
  test(
    'reconstructed schema3 upgrades only restore-local defaults and preserves existing identities',
    () async {
      // This is a reconstructed schema3 fixture (current schema minus the three
      // additive v4 columns), not evidence from a historical device binary.
      final dir = await Directory.systemTemp.createTemp('a09-schema3-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/store.sqlite');
      var db = AppDatabase.forTesting(NativeDatabase(file));
      await db.userDao.putUser(
        const UserEntity(
          id: 'local-profile',
          spareTime: Duration(minutes: 9),
          note: 'schema3',
        ),
      );
      final before = await db.select(db.users).getSingle();
      await db.close();
      final raw = sqlite3.open(file.path);
      raw.execute(
        'ALTER TABLE schedules DROP COLUMN requires_start_confirmation',
      );
      raw.execute('ALTER TABLE users DROP COLUMN restore_cleanup_pending');
      raw.execute('ALTER TABLE users DROP COLUMN reject_legacy_delivery');
      raw.execute('PRAGMA user_version=3');
      raw.dispose();
      db = AppDatabase.forTesting(NativeDatabase(file));
      try {
        final after = await db.select(db.users).getSingle();
        expect(after.storeIncarnation, before.storeIncarnation);
        expect(after.note, 'schema3');
        expect(after.dataRevision, before.dataRevision);
        expect(after.restoreCleanupPending, isFalse);
        expect(after.rejectLegacyDelivery, isFalse);
        expect(
          (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
            'user_version',
          ),
          4,
        );
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      } finally {
        await db.close();
      }
    },
  );
  for (final version in [1, 2]) {
    test(
      'frozen schema $version upgrades atomically and identities survive reopen/upsert',
      () async {
        final dir = await Directory.systemTemp.createTemp('a08-migration-');
        final file = File('${dir.path}/store.sqlite');
        final raw = sqlite3.open(file.path);
        raw.execute(
          File(
            'test/fixtures/database/schema_v$version.sql',
          ).readAsStringSync(),
        );
        raw.execute(
          "INSERT INTO users(id,spare_time,note,data_revision,last_exported_revision,eligible_outcome_count,on_time_outcome_count) VALUES('local-profile',17,'preserved',9,8,4,3)",
        );
        raw.execute("INSERT INTO places(id,place_name) VALUES('place','Home')");
        raw.execute(
          "INSERT INTO schedules(id,place_id,schedule_name,schedule_time,move_time,is_started,started_at,finished_at,done_status,preparation_frozen,score_contribution_recorded) VALUES('schedule','place','Historical','2030-01-01T10:00:00.000',0,0,100,200,'normalEnd',1,1)",
        );
        if (version == 2) {
          raw.execute(
            "INSERT INTO preparation_definitions(id,owner_id,scope,name,created_at) VALUES('definition','series','recurring','Owned',100)",
          );
          raw.execute(
            "INSERT INTO preparation_definition_steps(id,definition_id,name,minutes,position) VALUES('owned-step','definition','Owned step',0,0)",
          );
          raw.execute(
            "INSERT INTO recurring_schedule_segments(id,series_id,rule_json,schedule_json,preparation_id,from_slot,created_at) VALUES('root','series','{}','{}','definition','2030-01-01T10:00:00.000',100)",
          );
          raw.execute(
            "UPDATE schedules SET recurring_segment_id='root',recurring_slot_key='2030-01-01T10:00:00.000',recurring_ordinal=1,preparation_definition_id='definition' WHERE id='schedule'",
          );
        }
        raw.execute(
          "INSERT INTO preparation_schedules(id,schedule_id,preparation_name,preparation_time) VALUES('two','schedule','Second',0)",
        );
        raw.execute(
          "INSERT INTO preparation_schedules(id,schedule_id,preparation_name,preparation_time,next_preparation_id) VALUES('one','schedule','First',12,'two')",
        );
        raw.dispose();
        var db = AppDatabase.forTesting(NativeDatabase(file));
        try {
          final profile = await db.select(db.users).getSingle();
          final row = await db.select(db.schedules).getSingle();
          expect(profile.storeIncarnation, hasLength(32));
          expect(row.aggregateIncarnation, hasLength(32));
          expect(row.aggregateVersion, 0);
          if (version == 2) {
            final segment = await db
                .select(db.recurringScheduleSegments)
                .getSingle();
            expect(segment.rootSegmentId, 'root');
            expect(row.recurringSegmentId, 'root');
            expect(row.preparationDefinitionId, 'definition');
            expect(
              (await db.select(db.preparationDefinitionSteps).getSingle())
                  .minutes,
              0,
            );
          }
          expect(profile.dataRevision, 9);
          expect(profile.lastExportedRevision, 8);
          expect(profile.spareTime, 17);
          expect(row.startedAt?.millisecondsSinceEpoch, 100000);
          expect(row.finishedAt?.millisecondsSinceEpoch, 200000);
          expect(row.preparationFrozen, isTrue);
          expect(row.scoreContributionRecorded, isTrue);
          expect(
            (await db.preparationScheduleDao
                    .getPreparationSchedulesByScheduleId('schedule'))
                .ordered
                .preparationStepList
                .map((s) => s.id),
            ['one', 'two'],
          );
          await db.userDao.putUser(
            const UserEntity(
              id: 'local-profile',
              spareTime: Duration.zero,
              note: 'overwrite attempt',
            ),
          );
          await db.close();
          db = AppDatabase.forTesting(NativeDatabase(file));
          expect(
            (await db.select(db.users).getSingle()).storeIncarnation,
            profile.storeIncarnation,
          );
          expect(
            (await db.select(db.schedules).getSingle()).aggregateIncarnation,
            row.aggregateIncarnation,
          );
          expect(
            await db.customSelect('PRAGMA foreign_key_check').get(),
            isEmpty,
          );
          final fresh = AppDatabase.forTesting(NativeDatabase.memory());
          await fresh.customSelect('SELECT 1').get();
          for (final table in [
            'users',
            'schedules',
            'recurring_schedule_segments',
          ]) {
            final oldColumns =
                (await db.customSelect('PRAGMA table_info($table)').get())
                    .map((r) => r.read<String>('name'))
                    .toSet();
            final newColumns =
                (await fresh.customSelect('PRAGMA table_info($table)').get())
                    .map((r) => r.read<String>('name'))
                    .toSet();
            expect(oldColumns, newColumns);
          }
          await fresh.close();
        } finally {
          await db.close();
          await dir.delete(recursive: true);
        }
      },
    );
  }
  test(
    'unknown preexisting trigger is rejected before migration and preserves schema2',
    () async {
      final dir = await Directory.systemTemp.createTemp('a08-migration-fault-');
      final file = File('${dir.path}/store.sqlite');
      final raw = sqlite3.open(file.path);
      raw.execute(
        File('test/fixtures/database/schema_v2.sql').readAsStringSync(),
      );
      raw.execute(
        "INSERT INTO users(id,spare_time,note) VALUES('local-profile',17,'keep')",
      );
      raw.execute(
        "CREATE TRIGGER reject_migration BEFORE UPDATE ON users BEGIN SELECT RAISE(ABORT,'injected migration fault'); END",
      );
      raw.dispose();
      final db = AppDatabase.forTesting(NativeDatabase(file));
      await expectLater(db.select(db.users).get(), throwsA(anything));
      await db.close();
      final after = sqlite3.open(file.path);
      expect(after.select('PRAGMA user_version').single['user_version'], 2);
      expect(
        after.select('PRAGMA table_info(users)').map((r) => r['name']),
        isNot(contains('store_incarnation')),
      );
      expect(after.select('SELECT note FROM users').single['note'], 'keep');
      after.dispose();
      await dir.delete(recursive: true);
    },
  );
  test(
    'future database version is rejected without downgrade or data mutation',
    () async {
      final dir = await Directory.systemTemp.createTemp('a08-future-');
      final file = File('${dir.path}/store.sqlite');
      final raw = sqlite3.open(file.path);
      raw.execute(
        File('test/fixtures/database/schema_v2.sql').readAsStringSync(),
      );
      raw.execute('PRAGMA user_version=99');
      raw.dispose();
      final db = AppDatabase.forTesting(NativeDatabase(file));
      await expectLater(db.select(db.users).get(), throwsA(anything));
      await db.close();
      final after = sqlite3.open(file.path);
      expect(after.select('PRAGMA user_version').single['user_version'], 99);
      after.dispose();
      await dir.delete(recursive: true);
    },
  );
}
