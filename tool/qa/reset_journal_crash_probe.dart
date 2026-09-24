// Run only through verify_reset_crash_recovery.py, never against app data.
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/database/local_reset_protocol.dart';
import 'package:on_time_front/core/services/alarm_journal_store_native.dart';
import 'package:on_time_front/core/services/alarm_operation_coordinator.dart';
import 'package:on_time_front/core/services/alarm_ownership_journal.dart';
import 'package:on_time_front/core/services/alarm_registration_cleanup.dart';

import '../../test/domain/use-cases/reconcile_alarms_use_case_test.dart'
    as fixtures;
import '../../test/core/services/alarm_ownership_journal_test.dart' show record;

void main() {
  test(
    'isolated reset survives a killed host process',
    () async {
      final directory = Directory(Platform.environment['D03_PROBE_DIR']!);
      final point = Platform.environment['D03_PROBE_POINT']!;
      final recovering = Platform.environment['D03_PROBE_MODE'] == 'recover';
      final syntaxRecovery = const {
        'partial-first-pending',
        'recoveryMarked',
        'quarantinedPending',
        'recoveryVerified',
        'recoveryPublished',
      }.contains(point);
      final ready = File('${directory.path}/cut-ready');
      Future<void> cut(String stage) async {
        if (!recovering && point == stage) {
          await ready.writeAsString(stage, flush: true);
          await Completer<void>().future;
        }
      }

      final actions = _DiskActions(directory, cut);
      final store = FileAlarmJournalStore(
        () async => Directory('${directory.path}/journal'),
        checkpoint: (stage) async {
          if (syntaxRecovery) await cut(stage);
          if (stage == 'written') {
            final staged = File(
              '${directory.path}/journal/ownership-v1.json.pending',
            );
            final state = AlarmJournalSnapshot.decode(
              await staged.readAsString(),
            );
            if (state.reset == ResetPhase.none) {
              await cut('first-ownership-written');
            }
          }
          if (stage == 'renamed') {
            final committed = File(
              '${directory.path}/journal/ownership-v1.json',
            );
            final state = AlarmJournalSnapshot.decode(
              await committed.readAsString(),
            );
            if (state.reset == ResetPhase.pending && state.completed.isEmpty) {
              await cut('intent-renamed');
            }
            if (state.reset == ResetPhase.complete) {
              await cut('completion-renamed');
            }
          }
          if (stage == 'removed') await cut('journal-unlinked');
        },
      );
      final journal = AlarmOwnershipJournal(store);
      final gate = LocalDataOperationGate();
      final owner = AlarmOperationCoordinator(gate, journal: journal);
      addTearDown(() {
        owner.dispose();
        gate.dispose();
      });
      final registry = fixtures.FakeAlarmRegistryRepository();
      if (!recovering) {
        for (final step in ResetStep.values.where(
          (s) => s != ResetStep.deliveries,
        )) {
          await File(
            '${directory.path}/${step.name}',
          ).writeAsString('isolated fixture', flush: true);
        }
        registry.records = [record('probe-owned', 73)];
        if (syntaxRecovery) {
          final partial = File(
            '${directory.path}/journal/ownership-v1.json.pending',
          );
          await partial.parent.create(recursive: true);
          // Explicit damaged-bytes fixture; this does not claim interruption
          // inside the production write syscall or a simulated power failure.
          await partial.writeAsString(
            '{"version":1,"ownership":[',
            flush: true,
          );
          await cut('partial-first-pending');
        } else {
          await journal.remember(registry.records);
        }
      }
      final cleanup = AlarmRegistrationCleanup(
        registry,
        fixtures.FakeAlarmSchedulerService()
          ..nativeObservationFails = syntaxRecovery,
        fixtures.FakeFallbackAlarmNotificationService(),
        owner,
      );
      final result = await owner.cleanup(
        () => LocalResetProtocol(
          journal,
          cleanup,
          actions,
        ).run(begin: !recovering && !syntaxRecovery),
      );
      if (!recovering) fail('Requested kill point was not reached: $point');

      if (syntaxRecovery) {
        expect(result.recoveryRequired, false);
        expect(result.intentRecorded, false);
        expect(await actions.hasMarker(), false);
        final repaired = await journal.read();
        expect(repaired.reset, ResetPhase.none);
        // Fixture observations cannot certify Android native registrations.
        expect(repaired.unknownOwnership, true);
        for (final step in ResetStep.values.where(
          (s) => s != ResetStep.deliveries,
        )) {
          expect(
            await File('${directory.path}/${step.name}').readAsString(),
            'isolated fixture',
          );
        }
      } else if (point == 'first-ownership-written') {
        expect(result.recoveryRequired, false);
        expect(result.intentRecorded, false);
        expect(await File('${directory.path}/database').exists(), true);
        expect((await journal.read()).ownership.keys, ['localNotification:73']);
      } else {
        // Final unlink may have completed before SIGKILL; idle is then correct.
        expect(result.isComplete || !result.recoveryRequired, true);
        expect(await actions.hasMarker(), false);
        expect(await File('${directory.path}/database').exists(), false);
        expect((await journal.read()).reset, ResetPhase.none);
        for (final step in ResetStep.values.where(
          (s) => s != ResetStep.deliveries,
        )) {
          expect(await File('${directory.path}/${step.name}').exists(), false);
        }
      }
      await File(
        '${directory.path}/verified',
      ).writeAsString('passed', flush: true);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

class _DiskActions implements LocalResetActions {
  _DiskActions(this.directory, this.cut);
  final Directory directory;
  final Future<void> Function(String) cut;
  File get marker => File('${directory.path}/reset-marker');
  @override
  Future<bool> hasMarker() => marker.exists();
  @override
  Future<void> writeMarker() => marker.writeAsString('pending', flush: true);
  @override
  Future<void> removeMarker() async {
    if (await marker.exists()) await marker.delete();
    await cut('marker-removed');
  }

  @override
  Future<void> perform(ResetStep step) async {
    if (step == ResetStep.deliveries) return;
    final file = File('${directory.path}/${step.name}');
    if (await file.exists()) await file.delete();
    if (step == ResetStep.database) await cut('database-deleted');
  }
}
