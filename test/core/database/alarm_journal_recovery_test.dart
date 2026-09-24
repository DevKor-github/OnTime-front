import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:on_time_front/data/data_sources/alarm_registry_local_data_source.dart';
import 'package:on_time_front/data/repositories/alarm_registry_repository_impl.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/database/local_reset_protocol.dart';
import 'package:on_time_front/core/services/alarm_journal_store_native.dart';
import 'package:on_time_front/core/services/alarm_operation_coordinator.dart';
import 'package:on_time_front/core/services/alarm_ownership_journal.dart';
import 'package:on_time_front/core/services/alarm_registration_cleanup.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/entities/delivery_observation.dart';

import '../../domain/use-cases/reconcile_alarms_use_case_test.dart' as fixtures;
import '../services/alarm_ownership_journal_test.dart' show record;
import 'local_reset_protocol_test.dart' show FakeActions, VerifiedActions;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late File privateData;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp(
      'ontime-corrupt-recovery-',
    );
    privateData = File('${directory.path}/user-database-sentinel');
    await privateData.writeAsString('USER DATA AND KEY ARE PRESERVED');
  });
  tearDown(() async => directory.delete(recursive: true));

  RecoveryRig reopen({
    Future<void> Function(String)? checkpoint,
    bool ios = false,
    AlarmJournalStore? store,
    FakeActions? actions,
  }) {
    final rig = RecoveryRig(
      AlarmOwnershipJournal(
        store ??
            FileAlarmJournalStore(
              () async => directory,
              checkpoint: checkpoint,
            ),
      ),
      actions ?? FakeActions(),
      ios: ios,
    );
    addTearDown(rig.owner.dispose);
    return rig;
  }

  for (final suffix in ['', '.pending']) {
    test(
      'partial JSON in $suffix recovers fresh owner without resetting user data',
      () async {
        final file = File('${directory.path}/ownership-v1.json$suffix');
        await file.writeAsString('{"version":1,"ownership":[');
        final original = await file.readAsBytes();
        final rig = reopen();
        rig.registry.records = [record('known', 7)];
        rig.fallback.pendingFallback['orphan'] = const PendingDelivery(
          id: '8',
          scheduleId: 'orphan',
        );
        final result = await rig.run(begin: false);
        expect(result.recoveryRequired, false);
        expect(result.intentRecorded, false);
        expect(result.isComplete, false);
        expect(rig.actions.performed, isEmpty);
        expect(rig.actions.marker, false);
        expect(
          await privateData.readAsString(),
          'USER DATA AND KEY ARE PRESERVED',
        );
        final rebuilt = await reopen().journal.read();
        expect(rebuilt.reset, ResetPhase.none);
        expect(
          rebuilt.unknownOwnership,
          true,
        ); // Android cache != native absence.
        expect(rebuilt.ownership.keys.toSet(), {
          'localNotification:7',
          'localNotification:8',
        });
        expect(rig.fallback.canceledFallback, isEmpty);
        expect(rig.scheduler.canceledNative, isEmpty);
        expect(rig.fallback.scheduledFallback, isEmpty);
        expect(rig.scheduler.scheduledNative, isEmpty);
        final quarantine = File(
          '${directory.path}/ownership-v1.json.corrupt.0',
        );
        expect(await quarantine.readAsBytes(), original);
        final raw = await File(
          '${directory.path}/ownership-v1.json',
        ).readAsString();
        expect(raw, isNot(contains('PRIVATE')));
        expect(raw, isNot(contains('2030')));
        // Later startup sees reconstructed ownership instead of repair looping.
        expect((await reopen().run(begin: false)).recoveryRequired, false);
      },
    );
  }

  test(
    'only complete iOS OS observations resolve reconstructed uncertainty',
    () async {
      await File(
        '${directory.path}/ownership-v1.json',
      ).writeAsString('{broken');
      final rig = reopen(ios: true);
      rig.registry.records = [record('known', 7)];
      rig.scheduler.pendingNative.add('known');
      rig.fallback.pendingFallback['orphan'] = const PendingDelivery(
        id: '8',
        scheduleId: 'orphan',
      );
      expect((await rig.run(begin: false)).recoveryRequired, false);
      final rebuilt = await rig.journal.read();
      expect(rebuilt.unknownOwnership, false);
      expect(rebuilt.ownership.keys.toSet(), {
        'localNotification:7',
        'localNotification:8',
        'iosAlarmKit:known',
      });
      expect(rig.actions.performed, isEmpty);
    },
  );

  for (final uncertainty in [
    'nativeUnmapped',
    'nativeError',
    'fallbackError',
    'unownedNotification',
  ]) {
    test(
      'iOS $uncertainty remains partial without guessing ownership',
      () async {
        await File(
          '${directory.path}/ownership-v1.json',
        ).writeAsString('{broken');
        final rig = reopen(ios: true);
        switch (uncertainty) {
          case 'nativeUnmapped':
            rig.scheduler.unmappedNativeCount = 1;
          case 'nativeError':
            rig.scheduler.nativeObservationFails = true;
          case 'fallbackError':
            rig.fallback.observationFails = true;
          case 'unownedNotification':
            rig.fallback.pendingFallback['unknown'] = const PendingDelivery(
              id: '9',
            );
        }
        expect((await rig.run(begin: false)).recoveryRequired, false);
        expect((await rig.journal.read()).unknownOwnership, true);
        expect((await rig.journal.read()).ownership, isEmpty);
        expect(rig.actions.performed, isEmpty);
      },
    );
  }

  test(
    'secure reset marker resumes deletion but Android uncertainty remains',
    () async {
      await File(
        '${directory.path}/ownership-v1.json',
      ).writeAsString('{broken');
      final actions = FakeActions()..marker = true;
      final rig = reopen(actions: actions);
      final result = await rig.run(begin: false);
      expect(result.intentRecorded, true);
      expect(result.dataDeleted, true);
      expect(result.isComplete, false);
      expect((await rig.journal.read()).reset, ResetPhase.pending);
      expect((await rig.journal.read()).unknownOwnership, true);
      expect(actions.marker, true);
    },
  );

  test(
    'explicit reset after damage cleans quarantine only after complete receipt',
    () async {
      await File(
        '${directory.path}/ownership-v1.json.pending',
      ).writeAsString('{broken');
      final actions = VerifiedActions();
      final rig = reopen(actions: actions);
      final result = await rig.run(begin: true);
      expect(result.isComplete, true);
      expect(actions.marker, false);
      final files = await directory.list().map((entry) => entry.path).toList();
      expect(files, [
        privateData.path,
      ]); // Fixture action never deletes user files.
      expect((await reopen().run(begin: false)).intentRecorded, false);
    },
  );

  for (final raw in [
    '{"version":2}',
    '{"version":1,"reset":"complete","completed":[],"ownership":[]}',
    jsonEncode({
      'version': 1,
      'reset': 'none',
      'completed': [],
      'ownership': [
        {
          'provider': 'localNotification',
          'scheduleId': 'a',
          'id': 1,
          'pending': true,
        },
        {
          'provider': 'localNotification',
          'scheduleId': 'b',
          'id': 1,
          'pending': true,
        },
      ],
    }),
  ]) {
    test(
      'future version or impossible supported state is never automatically replaced: $raw',
      () async {
        final file = File('${directory.path}/ownership-v1.json');
        await file.writeAsString(raw);
        final rig = reopen();
        expect((await rig.run(begin: true)).recoveryRequired, true);
        expect(await file.readAsString(), raw);
        expect(rig.actions.performed, isEmpty);
        expect(rig.actions.marker, false);
        expect(await File('${file.path}.corrupt.0').exists(), false);
        expect(await File('${file.path}.recovering').exists(), false);
      },
    );
  }

  test('read I/O failure does not quarantine or authorize deletion', () async {
    final file = File('${directory.path}/ownership-v1.json');
    await file.writeAsString('{broken');
    final rig = reopen(
      store: FileAlarmJournalStore(() async {
        throw const FileSystemException('temporarily unavailable');
      }),
    );
    expect((await rig.run(begin: true)).recoveryRequired, true);
    expect(rig.actions.performed, isEmpty);
    expect(await file.readAsString(), '{broken');
    expect(await File('${file.path}.corrupt.0').exists(), false);
  });

  for (final point in [
    'recoveryMarked',
    'quarantinedMain',
    'written',
    'verified',
    'renamed',
    'readBack',
    'recoveryVerified',
    'recoveryPublished',
  ]) {
    test(
      'reconstruction interrupted at $point recovers through a new owner',
      () async {
        final file = File('${directory.path}/ownership-v1.json');
        await file.writeAsString('{damaged');
        final first = reopen(
          checkpoint: (stage) async {
            if (stage == point) throw StateError('process stopped');
          },
        );
        first.registry.records = [record('known', 7)];
        final failed = await first.run(begin: false);
        expect(failed.recoveryRequired, true);
        expect(first.actions.performed, isEmpty);
        final next = reopen();
        next.registry.records = [record('known', 7)];
        expect((await next.run(begin: false)).recoveryRequired, false);
        expect((await next.journal.read()).ownership.keys, [
          'localNotification:7',
        ]);
        expect((await next.journal.read()).unknownOwnership, true);
        expect(next.actions.performed, isEmpty);
        expect(
          await privateData.readAsString(),
          'USER DATA AND KEY ARE PRESERVED',
        );
      },
    );
  }

  test(
    'first pending quarantine crash resumes without deleting user data',
    () async {
      final staged = File('${directory.path}/ownership-v1.json.pending');
      await staged.writeAsString('{partial first generation');
      final first = reopen(
        checkpoint: (stage) async {
          if (stage == 'quarantinedPending') {
            throw StateError('process stopped');
          }
        },
      );
      expect((await first.run(begin: false)).recoveryRequired, true);
      expect(await staged.exists(), false);
      expect(
        await File('${directory.path}/ownership-v1.json.recovering').exists(),
        true,
      );
      final next = reopen();
      expect((await next.run(begin: false)).recoveryRequired, false);
      expect((await next.journal.read()).unknownOwnership, true);
      expect(next.actions.performed, isEmpty);
      expect(
        await privateData.readAsString(),
        'USER DATA AND KEY ARE PRESERVED',
      );
    },
  );

  test(
    'unverified reconstructed reset journal cannot start deletion or OS cancellation',
    () async {
      await File(
        '${directory.path}/ownership-v1.json',
      ).writeAsString('{damaged');
      final first = reopen(
        checkpoint: (stage) async {
          if (stage == 'recoveryVerified') {
            throw StateError('lost verification');
          }
        },
      );
      first.registry.records = [record('owned', 8)];
      final result = await first.run(begin: true);
      expect(result.recoveryRequired, true);
      expect(result.isComplete, false);
      expect(first.actions.performed, isEmpty);
      expect(first.actions.marker, false);
      expect(first.fallback.canceledFallback, isEmpty);
      expect(first.scheduler.canceledNative, isEmpty);
      // Secure intent was not published, so damage-recovery cannot infer it from
      // a candidate file while the recovery transaction itself is incomplete.
      final next = reopen();
      next.registry.records = [record('owned', 8)];
      expect((await next.run(begin: false)).intentRecorded, false);
      expect(next.actions.performed, isEmpty);
      expect((await next.journal.read()).reset, ResetPhase.none);
    },
  );

  for (final ios in [true, false]) {
    test(
      'real corrupt registry marker is resolved only with complete iOS evidence: $ios',
      () async {
        SharedPreferences.setMockInitialValues({
          'scheduled_alarm_registry': '{PRIVATE corruption',
          'unrelated_user_preference': 'preserve',
        });
        final main = File('${directory.path}/ownership-v1.json');
        await main.writeAsString('{broken');
        final rig = reopen(ios: ios);
        final source = AlarmRegistryLocalDataSourceImpl();
        final registry = AlarmRegistryRepositoryImpl(localDataSource: source);
        final cleanup = AlarmRegistrationCleanup(
          registry,
          rig.scheduler,
          rig.fallback,
          rig.owner,
        );
        final result = await rig.owner.cleanup(
          () => LocalResetProtocol(
            rig.journal,
            cleanup,
            rig.actions,
          ).run(begin: false),
        );
        expect(result.recoveryRequired, false);
        expect(await source.hasUnresolvedOwnership(), !ios);
        await rig.owner.loadRecords(registry);
        expect((await rig.journal.read()).unknownOwnership, !ios);
        expect(
          (await SharedPreferences.getInstance()).getString(
            'unrelated_user_preference',
          ),
          'preserve',
        );
        expect(rig.actions.performed, isEmpty);
      },
    );
  }

  test(
    'legacy marker clear failure stays closed and fresh owner retries after journal verification',
    () async {
      SharedPreferences.setMockInitialValues({
        'scheduled_alarm_registry': '{PRIVATE',
      });
      final main = File('${directory.path}/ownership-v1.json');
      await main.writeAsString('{broken');
      final first = reopen(ios: true);
      final source = FailingIntegritySource(first.journal);
      final registry = AlarmRegistryRepositoryImpl(localDataSource: source);
      final cleanup = AlarmRegistrationCleanup(
        registry,
        first.scheduler,
        first.fallback,
        first.owner,
      );
      final result = await first.owner.cleanup(
        () => LocalResetProtocol(
          first.journal,
          cleanup,
          first.actions,
        ).run(begin: false),
      );
      expect(result.recoveryRequired, true);
      expect(source.sawVerifiedJournal, true);
      expect(await source.hasUnresolvedOwnership(), true);
      expect((await first.journal.read()).unknownOwnership, true);
      expect(first.actions.performed, isEmpty);
      final next = reopen(ios: true);
      final nextRegistry = AlarmRegistryRepositoryImpl(
        localDataSource: AlarmRegistryLocalDataSourceImpl(),
      );
      final nextCleanup = AlarmRegistrationCleanup(
        nextRegistry,
        next.scheduler,
        next.fallback,
        next.owner,
      );
      expect(
        (await next.owner.cleanup(
          () => LocalResetProtocol(
            next.journal,
            nextCleanup,
            next.actions,
          ).run(begin: false),
        )).recoveryRequired,
        false,
      );
      await next.owner.loadRecords(nextRegistry);
      expect(await nextRegistry.hasUnresolvedOwnership(), false);
      expect((await next.journal.read()).unknownOwnership, false);
      expect(next.actions.performed, isEmpty);
    },
  );

  test(
    'journal-only uncertainty from temporary iOS observation failure converges on fresh startup',
    () async {
      final main = File('${directory.path}/ownership-v1.json');
      await main.writeAsString('{broken');
      final first = reopen(ios: true);
      first.fallback.observationFails = true;
      final registry = AlarmRegistryRepositoryImpl(
        localDataSource: AlarmRegistryLocalDataSourceImpl(),
      );
      final cleanup = AlarmRegistrationCleanup(
        registry,
        first.scheduler,
        first.fallback,
        first.owner,
      );
      expect(
        (await first.owner.cleanup(
          () => LocalResetProtocol(
            first.journal,
            cleanup,
            first.actions,
          ).run(begin: false),
        )).recoveryRequired,
        false,
      );
      expect((await first.journal.read()).unknownOwnership, true);
      expect(await registry.hasUnresolvedOwnership(), false);
      final next = reopen(ios: true);
      final nextRegistry = AlarmRegistryRepositoryImpl(
        localDataSource: AlarmRegistryLocalDataSourceImpl(),
      );
      final nextCleanup = AlarmRegistrationCleanup(
        nextRegistry,
        next.scheduler,
        next.fallback,
        next.owner,
      );
      expect(
        (await next.owner.cleanup(
          () => LocalResetProtocol(
            next.journal,
            nextCleanup,
            next.actions,
          ).run(begin: false),
        )).recoveryRequired,
        false,
      );
      expect((await next.journal.read()).unknownOwnership, false);
      expect((await next.journal.read()).reset, ResetPhase.none);
      expect(next.actions.performed, isEmpty);
      expect(
        await privateData.readAsString(),
        'USER DATA AND KEY ARE PRESERVED',
      );
    },
  );

  test(
    'notification unmappedCount keeps uncertainty even with an empty entry list',
    () async {
      final rig = reopen(ios: true);
      final cleanup = AlarmRegistrationCleanup(
        rig.registry,
        rig.scheduler,
        UnmappedFallback(),
        rig.owner,
      );
      final rebuilt = await rig.owner.cleanup(cleanup.reconstructOwnership);
      expect(rebuilt.unknownOwnership, true);
      expect(rebuilt.ownership, isEmpty);
    },
  );

  test('invalid UTF-8 is syntax corruption, not an empty journal', () async {
    final main = File('${directory.path}/ownership-v1.json');
    await main.writeAsBytes([0xff, 0xfe, 0x7b]);
    final rig = reopen();
    expect((await rig.run(begin: false)).recoveryRequired, false);
    expect((await rig.journal.read()).unknownOwnership, true);
    expect(await File('${main.path}.corrupt.0').readAsBytes(), [
      0xff,
      0xfe,
      0x7b,
    ]);
    expect(rig.actions.performed, isEmpty);
  });

  test('quarantine alone cannot be mistaken for a new installation', () async {
    await File(
      '${directory.path}/ownership-v1.json.corrupt.0',
    ).writeAsString('{damaged');
    final rig = reopen();
    await expectLater(rig.journal.read(), throwsA(isA<AlarmJournalCorrupt>()));
    expect((await rig.run(begin: false)).recoveryRequired, false);
    expect((await rig.journal.read()).unknownOwnership, true);
    expect(rig.actions.performed, isEmpty);
  });

  test(
    'future staged version is not overwritten beside a valid committed journal',
    () async {
      final rig = reopen();
      await rig.journal.remember([record('existing', 1)]);
      final main = File('${directory.path}/ownership-v1.json');
      final before = await main.readAsBytes();
      final staged = File('${main.path}.pending');
      await staged.writeAsString('{"version":2}');
      await expectLater(
        rig.journal.remember([record('new', 2)]),
        throwsA(isA<AlarmJournalUnsupported>()),
      );
      expect(await main.readAsBytes(), before);
      expect(await staged.readAsString(), '{"version":2}');
    },
  );

  test(
    'recovery refuses a future staged format even beside damaged main',
    () async {
      final main = File('${directory.path}/ownership-v1.json');
      final staged = File('${main.path}.pending');
      await main.writeAsString('{damaged');
      await staged.writeAsString('{"version":2}');
      final rig = reopen();
      expect((await rig.run(begin: false)).recoveryRequired, true);
      expect(await main.readAsString(), '{damaged');
      expect(await staged.readAsString(), '{"version":2}');
      expect(await File('${main.path}.recovering').exists(), false);
    },
  );
}

class RecoveryRig {
  RecoveryRig(this.journal, this.actions, {required bool ios}) {
    owner = AlarmOperationCoordinator(
      LocalDataOperationGate(),
      journal: journal,
    );
    fallback.timingPermission = ios
        ? AlarmPermissionState.unsupported
        : AlarmPermissionState.granted;
    cleanup = AlarmRegistrationCleanup(registry, scheduler, fallback, owner);
  }
  final AlarmOwnershipJournal journal;
  final FakeActions actions;
  final registry = fixtures.FakeAlarmRegistryRepository();
  final fallback = fixtures.FakeFallbackAlarmNotificationService();
  final scheduler = fixtures.FakeAlarmSchedulerService();
  late final AlarmOperationCoordinator owner;
  late final AlarmRegistrationCleanup cleanup;
  Future<LocalResetResult> run({required bool begin}) => owner.cleanup(
    () => LocalResetProtocol(
      journal,
      cleanup,
      actions,
      onIntent: owner.gate.invalidate,
    ).run(begin: begin),
  );
}

class FailingIntegritySource extends AlarmRegistryLocalDataSourceImpl {
  FailingIntegritySource(this.journal);
  final AlarmOwnershipJournal journal;
  bool sawVerifiedJournal = false;
  @override
  Future<void> clearResolvedOwnership() async {
    final state = await journal.read();
    sawVerifiedJournal =
        !state.unknownOwnership && state.reset == ResetPhase.none;
    throw StateError('marker removal failed');
  }
}

class UnmappedFallback extends fixtures.FakeFallbackAlarmNotificationService {
  @override
  Future<DeliveryObservation> observePending() async =>
      const DeliveryObservation(
        source: DeliveryObservationSource.iosNotificationCenter,
        unmappedCount: 1,
        entries: [],
      );
}
