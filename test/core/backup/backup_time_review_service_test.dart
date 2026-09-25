// Real authenticated ciphertext and service ownership with explicit in-memory
// SQLite ingestion/staging adapters. This is not SQLCipher or native UI proof.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:on_time_front/core/backup/backup_crypto.dart';
import 'package:on_time_front/core/backup/backup_ingestion_store.dart';
import 'package:on_time_front/core/backup/backup_service.dart';
import 'package:on_time_front/core/backup/restore_staging.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/database/restore_runtime_identity.dart';
import 'package:on_time_front/core/services/app_metadata_service.dart';
import 'package:on_time_front/domain/entities/backup_processing.dart';
import 'package:on_time_front/domain/entities/backup_restore_selection.dart';
import 'package:on_time_front/domain/entities/backup_time_review.dart';
import 'package:on_time_front/domain/entities/civil_date_time.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import '../../helpers/noop_alarm_cleanup.dart';
import '../../helpers/sodium_test_loader.dart';
import 'backup_validation_contract_test.dart' show validBackup;

const _password = 'portable review password';
Map<String, dynamic> _input() {
  final value = jsonDecode(jsonEncode(validBackup())) as Map<String, dynamic>;
  value['schedules'][0].addAll({
    'civilTime': '2031-01-02T09:00:00.123456',
    'timeZoneId': 'Old/Removed_Service_Zone',
    'occurrenceOffsetSeconds': 0,
  });
  return value;
}

class _Metadata implements AppMetadataProvider {
  @override
  Future<AppMetadata> getMetadata() async =>
      const AppMetadata(version: '1.0.0', buildNumber: '1');
}

class _AlarmCleanup extends NoopAlarmCleanup {
  int calls = 0;
  Future<void> Function()? onDataReplacement;
  @override
  Future<void> call() async {
    calls++;
  }

  @override
  Future<void> forDataReplacement() async {
    calls++;
    await onDataReplacement?.call();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase active;
  late BackupService service;
  late BackupCrypto crypto;
  late BackupProcessingOwner owner;
  late LocalDataOperationGate gate;
  late _AlarmCleanup alarms;
  late DateTime now;
  var stagingCreates = 0;
  var stagingReleases = 0;
  AppDatabase? lastStaging;
  Completer<void>? stagingEntered;
  Completer<void>? allowStaging;
  final stores = <BackupIngestionStore>[];
  final selections = <BackupRestoreSelection>[];

  Future<String> activeSnapshot() async {
    final tables = await active
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
        )
        .get();
    final result = <String, List<String>>{};
    for (final table in tables) {
      final name = table.read<String>('name');
      final quoted = name.replaceAll('"', '""');
      final rows = await active.customSelect('SELECT * FROM "$quoted"').get();
      result[name] = rows.map((row) => jsonEncode(row.data)).toList()..sort();
    }
    return jsonEncode(result);
  }

  Future<Uint8List> encrypted([Map<String, dynamic>? value]) => crypto.encrypt(
    plaintext: Uint8List.fromList(utf8.encode(jsonEncode(value ?? _input()))),
    password: _password,
  );

  Future<BackupTimeReviewInput> beginReview([Uint8List? ciphertext]) async {
    final selected = await service.reviewEncryptedBackup(
      ciphertext ?? await encrypted(),
      _password,
    );
    selections.add(selected);
    expect(selected, isA<BackupTimeReviewInput>());
    return selected as BackupTimeReviewInput;
  }

  Future<BackupTimeFieldReview> fieldReview(
    BackupTimeReviewInput review, {
    String civil = '2031-01-02T09:00:00.123456',
  }) async {
    final issue = (await review.issues()).items.single;
    final summary = review.summary;
    return review.review(
      BackupTimeDraft(
        identity: summary.identity,
        revision: summary.revision,
        rulesIdentity: summary.rulesIdentity,
        issueId: issue.id,
        civil: CivilDateTime.parse(civil),
        zone: 'UTC',
      ),
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    now = DateTime.utc(2030, 1, 1);
    stagingCreates = 0;
    stagingReleases = 0;
    lastStaging = null;
    stagingEntered = null;
    allowStaging = null;
    stores.clear();
    selections.clear();
    active = AppDatabase.forTesting(NativeDatabase.memory());
    await active.userDao.putUser(
      const UserEntity(
        id: 'local-profile',
        spareTime: Duration(minutes: 7),
        note: 'Keep active data',
        isOnboardingCompleted: true,
      ),
    );
    owner = BackupProcessingOwner();
    gate = LocalDataOperationGate();
    alarms = _AlarmCleanup();
    crypto = BackupCrypto(sodiumLoader: loadSodiumForTest);
    service = BackupService(
      active,
      _Metadata(),
      alarms,
      now: () => now,
      crypto: crypto,
      processingOwner: owner,
      operationGate: gate,
      runtimeIdentity: RestoreRuntimeIdentity(),
      cleanupPlatform: () async {},
      ingestionFactory: (budget) async {
        final store = BackupIngestionStore.memoryForTesting(budget);
        stores.add(store);
        return store;
      },
      stagingFactory: () async {
        stagingCreates++;
        stagingEntered?.complete();
        if (allowStaging != null) await allowStaging!.future;
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        lastStaging = database;
        return RestoreStaging(database, () async {
          stagingReleases++;
          await database.close();
        });
      },
    );
  });
  tearDown(() async {
    for (final selection in selections.reversed) {
      await selection.dispose();
    }
    for (final store in stores) {
      await store.release();
    }
    await active.close();
    gate.dispose();
  });

  test(
    'authenticated time review retains one lease and changes no active data or alarms',
    () async {
      final before = await activeSnapshot();
      final review = await beginReview();
      expect(review.summary.independentStructureChecked, isTrue);
      expect(review.summary.issueCount, 1);
      expect(review, isNot(isA<BackupRestoreInput>()));
      expect(owner.active, isNotNull);
      expect(stagingCreates, 0);
      expect(alarms.calls, 0);
      expect(gate.generation, 0);
      expect(await activeSnapshot(), before);
      await expectLater(
        service.reviewEncryptedBackup(await encrypted(), _password),
        throwsA(
          isA<DataOperationException>().having(
            (e) => e.failure,
            'busy lease',
            DataOperationFailure.busy,
          ),
        ),
      );
      await review.dispose();
      expect(owner.active, isNull);
      expect(await activeSnapshot(), before);
    },
  );

  for (final corruption in ['wrong password', 'final tag', 'trailing byte']) {
    test('$corruption cannot create a review owner or ready staging', () async {
      final before = await activeSnapshot();
      var bytes = await encrypted();
      if (corruption == 'final tag') {
        bytes = Uint8List.fromList(bytes);
        bytes[bytes.length - 1] ^= 1;
      } else if (corruption == 'trailing byte') {
        bytes = Uint8List.fromList([...bytes, 0]);
      }
      await expectLater(
        service.reviewEncryptedBackup(
          bytes,
          corruption == 'wrong password'
              ? 'incorrect review password'
              : _password,
        ),
        throwsA(isA<BackupProcessingFailure>()),
      );
      expect(owner.active, isNull);
      expect(stagingCreates, 0);
      expect(alarms.calls, 0);
      expect(await activeSnapshot(), before);
    });
  }

  test(
    'a time issue cannot hide an independent duplicate schedule identity',
    () async {
      final before = await activeSnapshot();
      final input = _input();
      input['schedules'].add(Map<String, dynamic>.from(input['schedules'][0]));
      await expectLater(
        service.reviewEncryptedBackup(await encrypted(input), _password),
        throwsA(
          isA<BackupProcessingFailure>().having(
            (e) => e.kind,
            'hard graph failure',
            BackupFailureKind.dataInvariant,
          ),
        ),
      );
      expect(owner.active, isNull);
      expect(stagingCreates, 0);
      expect(await activeSnapshot(), before);
    },
  );

  test(
    'accepted edit retires its old review and transfers the lease only to fresh ready input',
    () async {
      final before = await activeSnapshot();
      final ciphertext = await encrypted();
      final originalCiphertext = Uint8List.fromList(ciphertext);
      final review = await beginReview(ciphertext);
      final lease = owner.active;
      final originalRevision = review.summary.revision;
      final field = await fieldReview(review);
      final choice = BackupTimeChoice(review: field, offsetSeconds: 0);
      expect(field.choices.single.offsetSeconds, 0);
      await review.choose(choice);
      final acceptedRevision = review.summary.revision;
      expect(acceptedRevision, greaterThan(originalRevision));
      await expectLater(
        review.choose(choice),
        throwsA(isA<BackupTimeReviewStale>()),
      );
      expect(review.summary.revision, acceptedRevision);
      expect(stagingCreates, 0);
      final ready = await review.revalidate();
      selections.add(ready);
      expect(ready, isA<BackupRestoreInput>());
      expect(stagingCreates, 1);
      expect(owner.active, same(lease));
      await review.dispose();
      expect(owner.active, same(lease));
      await expectLater(
        () => review.revalidate(),
        throwsA(isA<BackupTimeReviewStale>()),
      );
      final row = await lastStaging!.select(lastStaging!.schedules).getSingle();
      expect(row.timeZoneId, 'UTC');
      expect(row.occurrenceOffsetSeconds, 0);
      expect(row.isStarted, isFalse);
      expect(
        (await lastStaging!
                .customSelect('SELECT schedule_time FROM schedules')
                .getSingle())
            .read<String>('schedule_time'),
        '2031-01-02T09:00:00.123456',
      );
      expect(ciphertext, originalCiphertext);
      expect((ready as BackupRestoreInput).preview.scheduleCount, 1);
      expect(await activeSnapshot(), before);
      expect(alarms.calls, 0);
      await ready.dispose();
      expect(owner.active, isNull);
      expect(stagingReleases, 1);
    },
  );

  test(
    'clock rewind retires a field confirmation instead of silently applying it',
    () async {
      final review = await beginReview();
      final field = await fieldReview(review);
      final revision = review.summary.revision;
      now = now.subtract(const Duration(seconds: 1));
      await expectLater(
        review.choose(BackupTimeChoice(review: field, offsetSeconds: 0)),
        throwsA(isA<BackupTimeReviewStale>()),
      );
      expect(review.summary.revision, revision);
      expect(stagingCreates, 0);
    },
  );

  test(
    'a changed explicit offset requires review while the strict entry rejects it',
    () async {
      final input = _input();
      input['schedules'][0]['timeZoneId'] = 'UTC';
      input['schedules'][0]['occurrenceOffsetSeconds'] = 3600;
      final bytes = await encrypted(input);
      final before = await activeSnapshot();
      await expectLater(
        service.previewEncryptedBackup(bytes, _password),
        throwsA(
          isA<BackupProcessingFailure>().having(
            (e) => e.kind,
            'explicit review required',
            BackupFailureKind.timeZoneChoiceRequired,
          ),
        ),
      );
      expect(owner.active, isNull);
      expect(stagingCreates, 0);
      final review = await beginReview(bytes);
      final issue = (await review.issues()).items.single;
      expect(issue.reason, BackupTimeIssueReason.changedOffset);
      expect(issue.selectedOffsetSeconds, 3600);
      final field = await fieldReview(review);
      expect(
        field.previousInstantUtc,
        DateTime.utc(2031, 1, 2, 8, 0, 0, 123, 456),
      );
      expect(
        field.choices.single.instantUtc,
        DateTime.utc(2031, 1, 2, 9, 0, 0, 123, 456),
      );
      expect(stagingCreates, 0);
      await review.choose(BackupTimeChoice(review: field, offsetSeconds: 0));
      final ready = await review.revalidate();
      selections.add(ready);
      expect(ready, isA<BackupRestoreInput>());
      expect(
        (await lastStaging!.select(lastStaging!.schedules).getSingle())
            .occurrenceOffsetSeconds,
        0,
      );
      expect(await activeSnapshot(), before);
    },
  );

  test(
    'a unique future null offset stays null without manufacturing historical selection',
    () async {
      final input = _input();
      input['schedules'][0]['timeZoneId'] = 'UTC';
      input['schedules'][0]['occurrenceOffsetSeconds'] = null;
      final selected = await service.reviewEncryptedBackup(
        await encrypted(input),
        _password,
      );
      selections.add(selected);
      expect(selected, isA<BackupRestoreInput>());
      final row = await lastStaging!.select(lastStaging!.schedules).getSingle();
      expect(row.occurrenceOffsetSeconds, isNull);
      expect(row.startedAt, isNull);
      expect(row.isStarted, isFalse);
      expect((selected as BackupRestoreInput).preview.timezoneChangeCount, 0);
    },
  );

  for (final change in ['clock rewind', 'target passed']) {
    test(
      '$change during staging creation cannot publish stale ready authority',
      () async {
        final before = await activeSnapshot();
        final review = await beginReview();
        await review.choose(
          BackupTimeChoice(review: await fieldReview(review), offsetSeconds: 0),
        );
        stagingEntered = Completer<void>();
        allowStaging = Completer<void>();
        final pending = review.revalidate().then<Object>(
          (value) => value,
          onError: (Object error) => error,
        );
        await stagingEntered!.future;
        now = change == 'clock rewind'
            ? now.subtract(const Duration(seconds: 1))
            : DateTime.utc(2032);
        allowStaging!.complete();
        final outcome = await pending;
        if (outcome is BackupRestoreSelection) selections.add(outcome);
        expect(
          outcome,
          anyOf(
            isA<BackupTimeReviewStale>(),
            isA<DataOperationException>().having(
              (e) => e.failure,
              'stale preview',
              DataOperationFailure.stalePreview,
            ),
          ),
        );
        expect(stagingReleases, 1);
        expect(await activeSnapshot(), before);
        expect(alarms.calls, 0);
        await review.dispose();
        expect(owner.active, isNull);
      },
    );

    test(
      '$change after ready is rejected before replacement generation or alarm cleanup',
      () async {
        final before = await activeSnapshot();
        final review = await beginReview();
        await review.choose(
          BackupTimeChoice(review: await fieldReview(review), offsetSeconds: 0),
        );
        final selected = await review.revalidate();
        selections.add(selected);
        expect(selected, isA<BackupRestoreCandidate>());
        now = change == 'clock rewind'
            ? now.subtract(const Duration(seconds: 1))
            : DateTime.utc(2032);
        await expectLater(
          service.applyRestoreWithReceipt(selected as BackupRestoreCandidate),
          throwsA(
            isA<DataOperationException>().having(
              (e) => e.failure,
              'stale preview',
              DataOperationFailure.stalePreview,
            ),
          ),
        );
        expect(gate.generation, 0);
        expect(alarms.calls, 0);
        expect(await activeSnapshot(), before);
      },
    );
  }

  test(
    'expiry during alarm cleanup preserves active data and reports the claimed cleanup generation',
    () async {
      final before = await activeSnapshot();
      final review = await beginReview();
      await review.choose(
        BackupTimeChoice(review: await fieldReview(review), offsetSeconds: 0),
      );
      final selected = await review.revalidate();
      selections.add(selected);
      final entered = Completer<void>();
      final resume = Completer<void>();
      alarms.onDataReplacement = () async {
        entered.complete();
        await resume.future;
      };
      final pending = service
          .applyRestoreWithReceipt(selected as BackupRestoreCandidate)
          .then<Object>((value) => value, onError: (Object error) => error);
      await entered.future;
      now = DateTime.utc(2032);
      resume.complete();
      final outcome = await pending;
      expect(
        outcome,
        isA<DataOperationException>()
            .having(
              (e) => e.failure,
              'stale preview',
              DataOperationFailure.stalePreview,
            )
            .having((e) => e.followUpPending, 'cleanup already claimed', isTrue)
            .having((e) => e.generation, 'claimed generation', 1),
      );
      expect(gate.generation, 1);
      expect(alarms.calls, 1);
      expect(await activeSnapshot(), before);
    },
  );

  test(
    'discard during staging creation cannot return a usable late candidate',
    () async {
      final before = await activeSnapshot();
      final review = await beginReview();
      await review.choose(
        BackupTimeChoice(review: await fieldReview(review), offsetSeconds: 0),
      );
      stagingEntered = Completer<void>();
      allowStaging = Completer<void>();
      final pending = review.revalidate().then<Object>(
        (value) => value,
        onError: (Object error) => error,
      );
      await stagingEntered!.future;
      final disposal = review.dispose();
      allowStaging!.complete();
      final outcome = await pending;
      await disposal;
      expect(
        outcome,
        anyOf(
          isA<BackupTimeReviewStale>(),
          isA<BackupProcessingFailure>().having(
            (e) => e.kind,
            'cancelled owner',
            BackupFailureKind.userCancelled,
          ),
        ),
      );
      expect(owner.active, isNull);
      expect(stagingReleases, 1);
      expect(await activeSnapshot(), before);
      expect(alarms.calls, 0);
    },
  );
}
