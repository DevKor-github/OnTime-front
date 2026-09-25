import 'package:on_time_front/core/time/schedule_time_resolution.dart';
import 'package:on_time_front/data/mappers/domain_persistence_mappers.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/entities/civil_date_time.dart';
// Real secretstream authentication, SQLCipher ingestion/staging/active files,
// service replacement and cold reopen. Native alarm delivery is not exercised.
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/open.dart';
import 'package:on_time_front/core/backup/backup_crypto.dart';
import 'package:on_time_front/core/backup/backup_ingestion_store.dart';
import 'package:on_time_front/core/backup/backup_service.dart';
import 'package:on_time_front/core/backup/restore_staging.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/database/restore_runtime_identity.dart';
import 'package:on_time_front/core/services/app_metadata_service.dart';
import 'package:on_time_front/domain/entities/backup_processing.dart';
import 'package:on_time_front/domain/entities/backup_recurring_time_review.dart';
import 'package:on_time_front/domain/entities/backup_restore_selection.dart';
import 'package:on_time_front/domain/entities/backup_time_review.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';
import '../../helpers/noop_alarm_cleanup.dart';
import '../../helpers/sodium_test_loader.dart';
import 'backup_validated_ingestion_test.dart' show recurringBackup;

class _Metadata implements AppMetadataProvider {
  @override
  Future<AppMetadata> getMetadata() async =>
      const AppMetadata(version: '1.0.0', buildNumber: '1');
}

class _Alarms extends NoopAlarmCleanup {
  int calls = 0;
  @override
  Future<void> forDataReplacement() async {
    calls++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final library = Platform.environment['ONTIME_TEST_SQLCIPHER_LIBRARY'];
  if (library != null) open.overrideForAll(() => DynamicLibrary.open(library));
  for (final spare in <int?>[null, 60]) {
    for (final empty in [false, true]) {
      test(
        'authenticated ${empty ? 'zero-row' : 'materialized'} recurrence spare=$spare uses encrypted candidate and applies only verified ready',
        () async {
          SharedPreferences.setMockInitialValues({});
          final root = await Directory.systemTemp.createTemp(
            'a10-recurring-cipher-',
          );
          final liveFile = File('${root.path}/active.sqlite');
          AppDatabase database() => AppDatabase.forTesting(
            NativeDatabase(
              liveFile,
              setup: (db) =>
                  db.execute("PRAGMA key = 'owned-test-installation-key'"),
            ),
          );
          var active = database();
          final gate = LocalDataOperationGate();
          final processing = BackupProcessingOwner();
          final selections = <BackupRestoreSelection>[];
          addTearDown(() async {
            for (final value in selections.reversed) {
              await value.dispose();
            }
            await active.close();
            gate.dispose();
            await root.delete(recursive: true);
          });
          await active.userDao.putUser(
            const UserEntity(
              id: 'local-profile',
              spareTime: Duration(minutes: 7),
              note: 'ACTIVE-UNCHANGED-BEFORE-CONFIRM',
            ),
          );
          final originalUser = await active.select(active.users).getSingle();
          final crypto = BackupCrypto(sodiumLoader: loadSodiumForTest);
          final alarms = _Alarms();
          var stages = 0;
          AppDatabase? staged;
          final service = BackupService(
            active,
            _Metadata(),
            alarms,
            now: () => DateTime.utc(2030),
            crypto: crypto,
            processingOwner: processing,
            operationGate: gate,
            runtimeIdentity: RestoreRuntimeIdentity(),
            cleanupPlatform: () async {},
            ingestionFactory: (b) => BackupIngestionStore.create(
              b,
              root: Directory('${root.path}/ingestion'),
            ),
            stagingFactory: () async {
              stages++;
              final value = await RestoreStaging.create(
                root: Directory('${root.path}/staging'),
              );
              staged = value.database;
              return value;
            },
          );
          final input = recurringBackup(year: 2031);
          final raw = input['recurring']['segments'][0];
          final rule =
              jsonDecode(raw['ruleJson'] as String) as Map<String, dynamic>;
          rule['zone'] = 'Removed/Zone';
          rule['count'] = 5;
          raw['ruleJson'] = jsonEncode(rule);
          final base =
              jsonDecode(raw['scheduleJson'] as String) as Map<String, dynamic>;
          base['zone'] = 'Removed/Zone';
          base['spare'] = spare;
          input['profile']['spareTimeMinutes'] = 60;
          input['schedules'][0]['spareTimeMinutes'] = spare;
          raw['scheduleJson'] = jsonEncode(base);
          input['schedules'][0]['timeZoneId'] = 'Removed/Zone';
          if (empty) {
            input['schedules'] = [];
          } else {
            final other =
                recurringBackup(year: 2031)['schedules'][0]
                    as Map<String, dynamic>;
            other.removeWhere(
              (key, _) =>
                  key.startsWith('recurring') ||
                  key == 'preparationDefinitionId',
            );
            other['id'] = 'other';
            other['civilTime'] = '2031-01-03T08:30:00.000';
            input['schedules'].add(other);
          }
          const password = 'actual encrypted recurring plan password';
          final ciphertext = await crypto.encrypt(
            plaintext: Uint8List.fromList(utf8.encode(jsonEncode(input))),
            password: password,
          );
          final originalBytes = Uint8List.fromList(ciphertext);
          final review =
              await service.reviewEncryptedBackup(ciphertext, password)
                  as BackupTimeReviewInput;
          selections.add(review);
          expect(stages, 0);
          expect(alarms.calls, 0);
          expect(processing.active, isNotNull);
          final api = review as BackupRecurringTimeReviewPort;
          final issue = (await review.issues()).items.singleWhere(
            (e) => e.kind == BackupTimeFieldKind.recurrenceRule,
          );
          final summary = review.summary;
          Future<BackupRecurringTimePlan> planAt(int hour) =>
              api.reviewRecurrence(
                BackupRecurringTimeDraft(
                  identity: summary.identity,
                  revision: summary.revision,
                  rulesIdentity: summary.rulesIdentity,
                  issueId: issue.id,
                  rule: RecurrenceRule(
                    frequency: RecurrenceFrequency.daily,
                    start: DateTime.utc(2031, 1, 3, hour),
                    timeZoneId: 'UTC',
                    count: 3,
                  ),
                  endExplicitlyChosen: true,
                  replaceWholeSourceInterval: !empty,
                ),
              );
          var plan = await planAt(9);
          expect(
            plan.conflicts.earliestPreparationUtc,
            DateTime.utc(2031, 1, 3, spare == null ? 9 : 8),
          );
          expect(plan.conflicts.conflicts.isNotEmpty, !empty && spare == 60);
          if (!empty && spare == 60) {
            await expectLater(
              api.chooseRecurrence(
                BackupRecurringTimeChoice(
                  plan: plan,
                  confirmedDetachedIds: {},
                  confirmedUnmatchedExclusions: {},
                  confirmedWholeSourceReplacement: true,
                ),
              ),
              throwsA(isA<BackupTimeChoiceConflict>()),
            );
            expect(await active.select(active.users).getSingle(), originalUser);
            plan = await planAt(10);
            expect(plan.conflicts.conflicts, isEmpty);
          }
          await api.chooseRecurrence(
            BackupRecurringTimeChoice(
              plan: plan,
              confirmedDetachedIds: {},
              confirmedUnmatchedExclusions: {},
              acknowledgedPossibleIds: plan.conflicts.possibleOverlaps
                  .map((e) => e.id)
                  .toSet(),
              confirmedWholeSourceReplacement: !empty,
            ),
          );
          expect(review.summary.independentStructureChecked, isFalse);
          expect(stages, 0);
          expect(await active.select(active.users).getSingle(), originalUser);
          expect(await active.select(active.schedules).get(), isEmpty);
          expect(alarms.calls, 0);
          final ready = await review.revalidate() as BackupRestoreCandidate;
          selections.add(ready);
          expect(stages, 1);
          expect(
            (await staged!.customSelect('PRAGMA cipher_version').getSingle())
                .data
                .values
                .single,
            isNotEmpty,
          );
          expect(
            (await staged!.select(staged!.recurringScheduleSegments).get()),
            hasLength(2),
          );
          expect(ready.preview.scheduleCount, empty ? 0 : 2);
          expect(ciphertext, originalBytes);
          expect(alarms.calls, 0);
          expect(gate.generation, 0);
          for (final directory in ['ingestion', 'staging']) {
            final files =
                (await Directory('${root.path}/$directory').list().toList())
                    .whereType<File>()
                    .where((f) => f.path.endsWith('.sqlite'))
                    .toList();
            expect(files, isNotEmpty);
            for (final file in files) {
              expect(
                utf8.decode(
                  (await file.readAsBytes()).take(16).toList(),
                  allowMalformed: true,
                ),
                isNot(startsWith('SQLite format 3')),
              );
            }
          }
          await review
              .dispose(); // Transferred owner cannot release the ready lease.
          expect(processing.active, isNotNull);
          await service.applyRestore(ready);
          expect(alarms.calls, 1);
          expect(gate.generation, 1);
          expect(processing.active, isNull);
          await active.close();
          active = database();
          final rows = await active.select(active.schedules).get();
          expect(rows, hasLength(empty ? 0 : 2));
          if (!empty) {
            final row = rows.singleWhere((e) => e.id == 's1');
            expect(row.scheduleSpareTime?.inMinutes, spare);
            expect(row.id, 's1');
            expect(row.recurringSegmentId, isNot('seg'));
            expect(row.recurringOrdinal, 1);
            expect(row.preparationDefinitionId, 'def');
            expect(row.timeZoneId, 'UTC');
            expect(row.isStarted, isFalse);
            expect(row.requiresStartConfirmation, isTrue);
            final rawSchedule = (await active.scheduleDao.getScheduleById(
              's1',
            )).toScheduleEntity();
            final actual =
                ScheduleWithPreparationEntity.fromScheduleAndPreparationEntity(
                  rawSchedule,
                  const PreparationWithTimeEntity(preparationStepList: []),
                  timeResolution: ScheduleTimeResolver.resolve(
                    rawSchedule,
                    nowUtc: DateTime.utc(2030),
                  ),
                );
            expect(actual.totalDuration, Duration(minutes: spare ?? 0));
            expect(
              actual.preparationStartTime,
              plan.conflicts.earliestPreparationUtc,
            );
            expect(
              (await active.select(active.users).getSingle()).spareTime,
              60,
            );
          }
          final segments = await active
              .select(active.recurringScheduleSegments)
              .get();
          expect(segments, hasLength(2));
          final original = segments.singleWhere((e) => e.id == 'seg');
          expect(original.ruleJson, raw['ruleJson']);
          expect(original.fromSlot, raw['fromSlot']);
          expect(
            CivilDateTime.parse(original.beforeSlot!),
            CivilDateTime.parse(original.fromSlot),
          );
          expect(ciphertext, originalBytes);
        },
        skip: library == null
            ? 'Requires actual host SQLCipher library'
            : false,
      );
    }
  }
}
