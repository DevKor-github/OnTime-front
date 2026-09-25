import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/restore_delivery_cleanup.dart';
import 'package:on_time_front/core/database/local_reset_actions.dart';
import 'package:on_time_front/core/services/alarm_operation_coordinator.dart';
import 'package:on_time_front/core/services/alarm_registration_cleanup.dart';
import 'package:on_time_front/core/services/alarm_ownership_journal.dart';
import '../../domain/use-cases/alarm_reconciliation_concurrency_test.dart'
    as concurrency;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final nativeGlobalEmpty in [false, true]) {
    test(
      'production helper normalizes known ownership with global native=$nativeGlobalEmpty',
      () async {
        final rig = concurrency.Rig();
        addTearDown(rig.dispose);
        rig.repository.schedules = [rig.schedule('same')];
        await rig.reconcile();
        var deliveries = 0, launches = 0;
        final actions = DeviceLocalResetActions(
          clearNativeDeliveries: () async => nativeGlobalEmpty,
          clearDeliveries: () async {
            deliveries++;
          },
          clearLaunch: () async {
            launches++;
          },
          deleteFiles: () async =>
              throw StateError('Restore must not remove DB'),
          closeDatabase: () async =>
              throw StateError('Restore must not close DB'),
        );
        final cleanup = AlarmRegistrationCleanup(
          rig.registry,
          rig.scheduler,
          rig.fallback,
          rig.operations,
        );
        await cleanupRestoreDeliveries(
          rig.operations,
          actions: actions,
          registrationCleanup: cleanup,
        );
        expect(rig.registry.records, isEmpty);
        final journal = await rig.operations.journal.read();
        expect(journal.ownership, isEmpty);
        expect(journal.unknownOwnership, isFalse);
        expect(journal.reset, ResetPhase.none);
        expect(journal.completed, isEmpty);
        expect(deliveries, 1);
        expect(launches, 1);
        // Cleanup repeats safely and same provider ID can then be registered.
        await cleanupRestoreDeliveries(
          rig.operations,
          actions: actions,
          registrationCleanup: cleanup,
        );
        expect((await rig.reconcile()).armedScheduleIds, ['same']);
      },
    );
  }
  test(
    'unknown ownership remains pending without global evidence and resolves with it',
    () async {
      final rig = concurrency.Rig();
      addTearDown(rig.dispose);
      final state = await rig.operations.journal.read();
      state.unknownOwnership = true;
      await rig.operations.journal.save(state);
      final cleanup = AlarmRegistrationCleanup(
        rig.registry,
        rig.scheduler,
        rig.fallback,
        rig.operations,
      );
      DeviceLocalResetActions actions(bool empty) => DeviceLocalResetActions(
        clearNativeDeliveries: () async => empty,
        clearDeliveries: () async {},
        clearLaunch: () async {},
      );
      await expectLater(
        cleanupRestoreDeliveries(
          rig.operations,
          actions: actions(false),
          registrationCleanup: cleanup,
        ),
        throwsA(isA<AlarmCleanupIncomplete>()),
      );
      expect((await rig.operations.journal.read()).unknownOwnership, isTrue);
      await cleanupRestoreDeliveries(
        rig.operations,
        actions: actions(true),
        registrationCleanup: cleanup,
      );
      expect((await rig.operations.journal.read()).unknownOwnership, isFalse);
    },
  );
}
