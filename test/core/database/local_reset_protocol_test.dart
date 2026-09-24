import 'package:shared_preferences/shared_preferences.dart';
import 'package:on_time_front/data/data_sources/alarm_registry_local_data_source.dart';
import 'package:on_time_front/data/repositories/alarm_registry_repository_impl.dart';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/database/local_reset_protocol.dart';
import 'package:on_time_front/core/services/alarm_journal_store_native.dart';
import 'package:on_time_front/core/services/alarm_operation_coordinator.dart';
import 'package:on_time_front/core/services/alarm_ownership_journal.dart';
import 'package:on_time_front/core/services/alarm_registration_cleanup.dart';

import '../../domain/use-cases/reconcile_alarms_use_case_test.dart' as fixtures;
import '../services/alarm_ownership_journal_test.dart' show record;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late FakeActions actions;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('ontime-reset-protocol-');
    actions = FakeActions();
  });
  tearDown(() async => directory.delete(recursive: true));

  Rig reopen({AlarmJournalStore? store}) {
    final rig = Rig(
      AlarmOwnershipJournal(
        store ?? FileAlarmJournalStore(() async => directory),
      ),
      actions,
    );
    addTearDown(rig.owner.dispose);
    return rig;
  }

  test('legacy reset marker with no ownership is never an empty success', () async {
    actions.marker = true;
    final rig = reopen();
    final pending = await rig.run(begin: false);
    expect(pending.intentRecorded, true);
    expect(pending.dataDeleted, true);
    expect(pending.isComplete, false);
    expect(pending.completed, isNot(contains(ResetStep.deliveries)));
    expect((await rig.journal.read()).unknownOwnership, true);
    expect((await reopen().run(begin: false)).isComplete, false);
    final verified = VerifiedActions()..marker = true;
    final restarted = reopen();
    final complete = await restarted.owner.cleanup(() => LocalResetProtocol(
      restarted.journal, restarted.cleanup, verified).run(begin: false));
    expect(complete.isComplete, true);
  });

  test(
    'corrupt registry uncertainty survives preference deletion and restart',
    () async {
      SharedPreferences.setMockInitialValues({
        'scheduled_alarm_registry': 'PRIVATE corrupt',
      });
      final rig = reopen();
      final registry = AlarmRegistryRepositoryImpl(
        localDataSource: AlarmRegistryLocalDataSourceImpl(),
      );
      final cleanup = AlarmRegistrationCleanup(
        registry,
        fixtures.FakeAlarmSchedulerService(),
        rig.fallback,
        rig.owner,
      );
      final first = await rig.owner.cleanup(
        () =>
            LocalResetProtocol(rig.journal, cleanup, actions).run(begin: true),
      );
      expect(first.dataDeleted, true);
      expect(first.isComplete, false);
      expect((await rig.journal.read()).unknownOwnership, true);
      await (await SharedPreferences.getInstance()).clear();
      final restarted = reopen();
      final retry = await restarted.run(begin: false);
      expect(retry.isComplete, false);
      expect(retry.completed, isNot(contains(ResetStep.deliveries)));
      expect((await restarted.journal.read()).unknownOwnership, true);
      expect(
        await File('${directory.path}/ownership-v1.json').readAsString(),
        isNot(contains('PRIVATE')),
      );
    },
  );

  test(
    'unknown ownership clears only after an app-wide provider receipt',
    () async {
      final rig = reopen();
      await rig.journal.save(AlarmJournalSnapshot(unknownOwnership: true));
      final verified = VerifiedActions();
      final result = await rig.owner.cleanup(
        () => LocalResetProtocol(
          rig.journal,
          rig.cleanup,
          verified,
        ).run(begin: true),
      );
      expect(result.isComplete, true);
      expect((await rig.journal.read()).unknownOwnership, false);
    },
  );

  test(
    'ordinary ownership does not authorize reset or remove user data',
    () async {
      final rig = reopen();
      await rig.journal.remember([record('existing', 1)]);
      final receipt = await rig.run(begin: false);
      expect(receipt.intentRecorded, false);
      expect(receipt.isComplete, false);
      expect(actions.performed, isEmpty);
      expect((await reopen().journal.read()).ownership, hasLength(1));
    },
  );

  test(
    'returned cancel failure permits content deletion and survives fresh-instance retry',
    () async {
      final first = reopen();
      first.registry.records = [record('old', 1)];
      first.fallback.throwOnCancelIds.add('old');
      final pending = await first.run(begin: true);
      expect(pending.intentRecorded, true);
      expect(pending.isComplete, false);
      expect(pending.dataDeleted, true);
      expect(actions.marker, true);
      expect(first.owner.gate.isInvalidated, true);
      expect((await first.journal.read()).ownership.keys, [
        'localNotification:1',
      ]);

      final dataCalls = actions.performed
          .where((s) => s != ResetStep.deliveries)
          .toList();
      final restarted =
          reopen(); // Empty preference registry, independent journal retained.
      final complete = await restarted.run(begin: false);
      expect(complete.isComplete, true);
      expect(actions.marker, false);
      expect(
        restarted.fallback.canceledFallback.single.fallbackNotificationId,
        1,
      );
      expect(
        actions.performed.where((s) => s != ResetStep.deliveries),
        dataCalls,
      );
      expect((await restarted.journal.read()).reset, ResetPhase.none);
    },
  );

  for (final failedStep in ResetStep.values.where(
    (s) => s != ResetStep.deliveries,
  )) {
    test(
      'reopen retries only unconfirmed $failedStep deletion stage',
      () async {
        actions.failures.add(failedStep);
        final first = await reopen().run(begin: true);
        expect(first.isComplete, false);
        expect(first.completed, isNot(contains(failedStep)));
        expect(actions.marker, true);
        final countBefore = actions.performed.length;
        actions.failures.clear();
        final second = await reopen().run(begin: false);
        expect(second.isComplete, true);
        expect(actions.performed.skip(countBefore), [failedStep]);
      },
    );
  }

  test(
    'failed marker removal reopens completed journal without deleting data again',
    () async {
      actions.failMarkerRemoval = true;
      final first = await reopen().run(begin: true);
      expect(first.isComplete, false);
      expect((await reopen().journal.read()).reset, ResetPhase.complete);
      final calls = List<ResetStep>.of(actions.performed);
      actions.failMarkerRemoval = false;
      expect((await reopen().run(begin: false)).isComplete, true);
      expect(actions.performed, calls);
      expect(actions.marker, false);
    },
  );

  test(
    'completed-journal unlink failure cannot replay deletion against new content',
    () async {
      final failing = _RemoveFailure(
        FileAlarmJournalStore(() async => directory),
      );
      final first = await reopen(store: failing).run(begin: true);
      expect(first.isComplete, false);
      expect(actions.marker, false);
      expect((await reopen().journal.read()).reset, ResetPhase.complete);
      final calls = List<ResetStep>.of(actions.performed);
      expect((await reopen().run(begin: false)).isComplete, true);
      expect(actions.performed, calls);
      expect((await reopen().run(begin: false)).intentRecorded, false);
      expect(actions.performed, calls);
    },
  );

  test(
    'unverified intent write reports no completion and never deletes data',
    () async {
      final failing = _IntentWriteFailure(
        FileAlarmJournalStore(() async => directory),
      );
      final rig = reopen(store: failing);
      final result = await rig.run(begin: true);
      expect(result.intentRecorded, false);
      expect(result.completed, isEmpty);
      expect(result.dataDeleted, false);
      expect(actions.performed, isEmpty);
      expect(actions.marker, false);
      expect(rig.owner.gate.isInvalidated, true);
      // The storage error occurred after rename. A fresh process discovers the
      // committed intent, rather than treating the ambiguous response as rollback.
      expect((await reopen().journal.read()).reset, ResetPhase.pending);
      expect((await reopen().run(begin: false)).isComplete, true);
    },
  );
}

class Rig {
  Rig(this.journal, this.actions) {
    owner = AlarmOperationCoordinator(
      LocalDataOperationGate(),
      journal: journal,
    );
    cleanup = AlarmRegistrationCleanup(
      registry,
      fixtures.FakeAlarmSchedulerService(),
      fallback,
      owner,
    );
  }
  final AlarmOwnershipJournal journal;
  final FakeActions actions;
  final registry = fixtures.FakeAlarmRegistryRepository();
  final fallback = fixtures.FakeFallbackAlarmNotificationService();
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

class FakeActions implements LocalResetActions {
  bool marker = false;
  bool failMarkerRemoval = false;
  final failures = <ResetStep>{};
  final performed = <ResetStep>[];
  @override
  Future<bool> hasMarker() async => marker;
  @override
  Future<void> writeMarker() async {
    marker = true;
  }

  @override
  Future<void> removeMarker() async {
    if (failMarkerRemoval) throw StateError('marker unavailable');
    marker = false;
  }

  @override
  Future<void> perform(ResetStep step) async {
    performed.add(step);
    if (failures.contains(step)) throw StateError('stage failed');
  }
}

class _RemoveFailure implements AlarmJournalStore {
  _RemoveFailure(this.inner);
  final AlarmJournalStore inner;
  @override
  Future<String?> read() => inner.read();
  @override
  Future<void> write(String value) => inner.write(value);
  @override
  Future<void> remove() async => throw StateError('unlink failed');
}

class _IntentWriteFailure extends _RemoveFailure {
  _IntentWriteFailure(super.inner);
  @override
  Future<void> write(String value) async {
    await inner.write(value);
    if (AlarmJournalSnapshot.decode(value).reset == ResetPhase.pending) {
      throw StateError('lost acknowledgement after rename');
    }
  }
}

class VerifiedActions extends FakeActions
    implements ResetGlobalDeliveryCleanup {
  @override
  bool get allProvidersConfirmedEmpty =>
      performed.contains(ResetStep.deliveries);
}
