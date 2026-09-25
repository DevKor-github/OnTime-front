import 'dart:async';
import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/backup/backup_content.dart';
import 'package:on_time_front/core/backup/backup_export_snapshot.dart';
import 'package:on_time_front/core/backup/backup_limits.dart';
import 'package:on_time_front/core/backup/restore_staging.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/domain/entities/backup_processing.dart';

// Explicit ordinary SQLite workflow fixtures, not encryption/provider evidence.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase source;
  final cutoff = DateTime.utc(2026, 9, 24, 12);
  setUp(() async {
    source = AppDatabase.forTesting(NativeDatabase.memory());
    await source.customStatement(
      'INSERT INTO users '
      '(id,spare_time,note,data_revision,is_onboarding_completed,store_incarnation) '
      "VALUES ('local-profile',7,'before',9,1,'SOURCE-INSTALLATION-IDENTITY')",
    );
    await source.customStatement(
      "INSERT INTO places(id,place_name) VALUES ('place','Library')",
    );
    await source.customStatement(
      'INSERT INTO schedules '
      '(id,place_id,schedule_name,time_zone_id,schedule_time,move_time,occurrence_offset_seconds,'
      'is_started,aggregate_incarnation,last_mutation_id,requires_start_confirmation) '
      "VALUES ('schedule','place','Read','Asia/Seoul','2027-03-28T02:30:00.000',600000,32400,"
      "1,'SOURCE-AGGREGATE','SOURCE-MUTATION',1)",
    );
  });
  tearDown(() => source.close());

  Future<RestoreStaging> memoryStage() async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final stage = RestoreStaging(db, db.close);
    addTearDown(stage.release);
    return stage;
  }

  Future<BackupExportSnapshot> capture({
    BackupBudget? budget,
    RestoreStagingFactory? factory,
  }) async {
    final snapshot = await BackupExportSnapshot.create(
      source,
      cutoff: cutoff,
      sourceAppVersion: '1.0+7',
      sourcePlatform: 'android',
      budget: budget ?? BackupBudget(),
      stagingFactory: factory ?? memoryStage,
    );
    addTearDown(snapshot.release);
    return snapshot;
  }

  Future<List<int>> bytes(BackupExportSnapshot snapshot) =>
      snapshot.plaintext().expand((chunk) => chunk).toList();

  test(
    'two passes freeze revision/content while the active store changes',
    () async {
      final snapshot = await capture();
      final first = await bytes(snapshot);
      await source.customStatement(
        "UPDATE users SET note='after',data_revision=10",
      );
      await source.customStatement(
        "UPDATE schedules SET schedule_name='Edited'",
      );
      final second = await bytes(snapshot);
      expect(second, first);
      final json = jsonDecode(utf8.decode(first)) as Map<String, dynamic>;
      expect(json['dataRevision'], 9);
      expect(json['cutoff'], cutoff.toIso8601String());
      expect(json['profile']['note'], 'before');
      expect(json['schedules'].single['name'], 'Read');
      expect(json['schedules'].single['moveTimeMinutes'], 10);
      expect(json['schedules'].single['spareTimeMinutes'], isNull);
      expect(json['schedules'].single['civilTime'], '2027-03-28T02:30:00.000');
      final decoded = BackupContent.fromJson(json);
      expect(decoded.schedules.single.scheduleTime.hour, 2);
      expect(decoded.schedules.single.occurrenceOffsetSeconds, 32400);
      expect(snapshot.dataRevision, 9);
      expect(
        (await source
                .customSelect('SELECT note,data_revision FROM users')
                .getSingle())
            .data,
        {'note': 'after', 'data_revision': 10},
      );
    },
  );

  test(
    'SQL duration milliseconds become portable minutes with legacy truncation',
    () async {
      await source.customStatement(
        'UPDATE schedules SET move_time=1200000,schedule_spare_time=59999',
      );
      final json =
          jsonDecode(utf8.decode(await bytes(await capture())))
              as Map<String, dynamic>;
      final schedule = json['schedules'].single;
      expect(schedule['moveTimeMinutes'], 20);
      expect(schedule['spareTimeMinutes'], 0);
      expect(
        BackupContent.fromJson(json).schedules.single.moveTime,
        const Duration(minutes: 20),
      );
    },
  );

  test(
    'negative sub-minute SQL durations cannot truncate into valid zero',
    () async {
      for (final column in ['move_time', 'schedule_spare_time']) {
        await source.customStatement(
          'UPDATE schedules SET move_time=0,schedule_spare_time=NULL',
        );
        await source.customStatement('UPDATE schedules SET $column=-1');
        final snapshot = await capture();
        await expectLater(
          bytes(snapshot),
          throwsA(
            isA<BackupProcessingFailure>().having(
              (e) => e.kind,
              'kind',
              BackupFailureKind.dataInvariant,
            ),
          ),
        );
        await snapshot.release();
        expect(
          (await source
                  .customSelect('SELECT $column AS value FROM schedules')
                  .getSingle())
              .read<int>('value'),
          -1,
        );
      }
    },
  );

  test(
    'private snapshot is query-only and installation/runtime values never enter the payload',
    () async {
      late AppDatabase owned;
      final snapshot = await capture(
        factory: () async {
          final stage = await memoryStage();
          owned = stage.database;
          return stage;
        },
      );
      await expectLater(
        owned.customStatement("UPDATE users SET note='mutated'"),
        throwsA(isA<SqliteException>().having((e) => e.resultCode, 'code', 8)),
      );
      final text = utf8.decode(await bytes(snapshot));
      for (final value in [
        'SOURCE-INSTALLATION-IDENTITY',
        'SOURCE-AGGREGATE',
        'SOURCE-MUTATION',
        'requiresStartConfirmation',
        'isStarted',
        'aggregateIncarnation',
        'storeIncarnation',
      ]) {
        expect(text, isNot(contains(value)));
      }
      final state =
          (await owned
                  .customSelect(
                    'SELECT is_started,requires_start_confirmation FROM schedules',
                  )
                  .getSingle())
              .data;
      expect(state, {'is_started': 0, 'requires_start_confirmation': 0});
    },
  );

  test(
    'keyset copy includes negative/zero rowids and crosses bounded pages without loss',
    () async {
      await source.transaction(() async {
        for (final rowid in [-9, 0, ...List.generate(65, (i) => i + 10)]) {
          await source.customStatement(
            'INSERT INTO schedules '
            '(rowid,id,place_id,schedule_name,schedule_time,move_time) VALUES (?,?,?,?,?,?)',
            [
              rowid,
              's$rowid',
              'place',
              'Page $rowid',
              '2027-01-01T12:00:00.000',
              0,
            ],
          );
        }
      });
      final json =
          jsonDecode(utf8.decode(await bytes(await capture())))
              as Map<String, dynamic>;
      final ids = (json['schedules'] as List).map((s) => s['id']).toList();
      expect(ids.length, 68);
      expect(ids.toSet().length, 68);
      expect(ids, containsAll(['s-9', 's0', 's74', 'schedule']));
      expect((json['schedulePreparations'] as Map).keys.toSet(), ids.toSet());
    },
  );

  test(
    'raw forward preparation links and original template timestamps survive copying',
    () async {
      await source.transaction(() async {
        await source.customStatement('PRAGMA defer_foreign_keys = ON');
        await source.customStatement(
          'INSERT INTO preparation_users '
          '(id,user_id,preparation_name,preparation_time,next_preparation_id) VALUES (?,?,?,?,?)',
          ['head', 'local-profile', '준비', 0, 'tail'],
        );
        await source.customStatement(
          'INSERT INTO preparation_users '
          '(id,user_id,preparation_name,preparation_time) VALUES (?,?,?,?)',
          ['tail', 'local-profile', '마지막', 2000],
        );
        await source.customStatement(
          'INSERT INTO preparation_templates '
          '(id,template_name,created_at,updated_at) VALUES (?,?,?,?)',
          ['template', 'Template', 1700000000, 1700000600],
        );
        for (final position in [1, 0]) {
          await source.customStatement(
            'INSERT INTO preparation_template_steps '
            '(id,template_id,preparation_name,preparation_time,position) VALUES (?,?,?,?,?)',
            ['t$position', 'template', 'Step $position', position, position],
          );
        }
      });
      final json =
          jsonDecode(utf8.decode(await bytes(await capture())))
              as Map<String, dynamic>;
      expect(json['defaultPreparation'], [
        {'id': 'head', 'name': '준비', 'minutes': 0, 'nextId': 'tail'},
        {'id': 'tail', 'name': '마지막', 'minutes': 2000, 'nextId': null},
      ]);
      final template = json['templates'].single;
      expect(template['createdAt'], '2023-11-14T22:13:20.000Z');
      expect(template['updatedAt'], '2023-11-14T22:23:20.000Z');
      expect(template['preparation'], [
        {'id': 't0', 'name': 'Step 0', 'minutes': 0, 'nextId': 't1'},
        {'id': 't1', 'name': 'Step 1', 'minutes': 1, 'nextId': null},
      ]);
      expect(
        BackupContent.fromJson(json).defaultPreparation.totalDuration.inMinutes,
        2000,
      );
    },
  );

  test(
    'UTF-8 output pieces stay bounded through escape and surrogate boundaries',
    () async {
      final note = '${'가' * 3000}${'😀' * 2000}\n\\\u0000';
      await source.customStatement('UPDATE users SET note=?', [note]);
      final snapshot = await capture();
      final pieces = await snapshot.plaintext().toList();
      expect(pieces.every((p) => p.length <= 16384), isTrue);
      expect(pieces.length, greaterThan(1));
      expect(
        pieces.take(pieces.length - 1).every((p) => p.length == 16384),
        isTrue,
      );
      final json =
          jsonDecode(utf8.decode(pieces.expand((p) => p).toList()))
              as Map<String, dynamic>;
      expect(json['profile']['note'], note);
    },
  );

  test(
    'oversized source text fails and cleans the candidate without changing the source',
    () async {
      // Construct the large value inside SQLite, not a giant Dart source buffer.
      await source.customStatement(
        "UPDATE users SET note=replace(hex(zeroblob(32769)),'0','x')",
      );
      var releases = 0;
      await expectLater(
        capture(
          factory: () async {
            final db = AppDatabase.forTesting(NativeDatabase.memory());
            return RestoreStaging(db, () async {
              releases++;
              await db.close();
            });
          },
        ),
        throwsA(
          isA<BackupProcessingFailure>().having(
            (e) => e.kind,
            'kind',
            BackupFailureKind.resourceLimit,
          ),
        ),
      );
      expect(releases, 1);
      expect(
        (await source
                .customSelect('SELECT length(note) AS size FROM users')
                .getSingle())
            .read<int>('size'),
        65538,
      );
    },
  );

  test(
    'non-text source blob is rejected and a late copy failure rolls back target rows',
    () async {
      await source.customStatement(
        'UPDATE schedules SET schedule_note=zeroblob(1048576)',
      );
      final target = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(target.close);
      await expectLater(
        source.transaction(
          () => copyPortableBackupRows(source, target, budget: BackupBudget()),
        ),
        throwsA(
          isA<BackupProcessingFailure>().having(
            (e) => e.kind,
            'kind',
            BackupFailureKind.dataInvariant,
          ),
        ),
      );
      expect(
        (await target
                .customSelect('SELECT count(*) AS n FROM users')
                .getSingle())
            .read<int>('n'),
        0,
      );
      expect(
        (await target
                .customSelect('SELECT count(*) AS n FROM places')
                .getSingle())
            .read<int>('n'),
        0,
      );
      expect(
        (await source
                .customSelect(
                  'SELECT length(schedule_note) AS n FROM schedules',
                )
                .getSingle())
            .read<int>('n'),
        1048576,
      );
    },
  );

  test(
    'copy refuses an occupied destination without deleting or replacing it',
    () async {
      final target = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(target.close);
      await target.customStatement(
        "INSERT INTO places(id,place_name) VALUES ('keep','Original')",
      );
      await expectLater(
        copyPortableBackupRows(source, target, budget: BackupBudget()),
        throwsStateError,
      );
      expect(
        (await target
                .customSelect('SELECT id,place_name FROM places')
                .getSingle())
            .data,
        {'id': 'keep', 'place_name': 'Original'},
      );
    },
  );

  test(
    'cancelled encoder terminates before release and cannot start another pass',
    () async {
      final owner = BackupProcessingOwner();
      final lease = owner.acquire();
      await source.customStatement('UPDATE users SET note=?', ['가' * 10000]);
      final snapshot = await capture(budget: BackupBudget(lease: lease));
      final reader = StreamIterator(snapshot.plaintext());
      expect(await reader.moveNext(), isTrue);
      await expectLater(snapshot.release(), throwsStateError);
      lease.requestCancellation();
      await expectLater(
        reader.moveNext(),
        throwsA(isA<BackupProcessingFailure>()),
      );
      await reader.cancel();
      await snapshot.release();
      lease.release();
      await expectLater(snapshot.plaintext().drain<void>(), throwsStateError);
      expect(owner.active, isNull);
    },
  );

  test(
    'failed creation retains same-owner cleanup retry and the original rejection',
    () async {
      await source.customStatement(
        "UPDATE users SET note=replace(hex(zeroblob(32769)),'0','x')",
      );
      final owner = BackupProcessingOwner();
      final lease = owner.acquire();
      var closes = 0;
      late AppDatabase stageDb;
      await expectLater(
        capture(
          budget: BackupBudget(lease: lease),
          factory: () async {
            stageDb = AppDatabase.forTesting(NativeDatabase.memory());
            return RestoreStaging(stageDb, () async {
              if (++closes == 1) throw StateError('injected close failure');
              await stageDb.close();
            });
          },
        ),
        throwsA(
          isA<BackupProcessingCleanupFailure>().having(
            (e) => (e.originalError as BackupProcessingFailure).kind,
            'original',
            BackupFailureKind.resourceLimit,
          ),
        ),
      );
      expect(owner.active, same(lease));
      expect(lease.phase, BackupProcessingPhase.cleanupPending);
      await owner.retryCleanup();
      expect(closes, 2);
      expect(owner.active, isNull);
    },
  );
}
