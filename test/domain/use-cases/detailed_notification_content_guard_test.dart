import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/services/alarm_operation_coordinator.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'alarm_reconciliation_concurrency_test.dart' as fixtures;

void main() {
  test('a completed OFF never reauthorizes an old ON content permit', () {
    final gate = LocalDataOperationGate();
    final owner = AlarmOperationCoordinator(gate);
    addTearDown(owner.dispose);
    addTearDown(gate.dispose);
    final oldOn = owner.captureContentPermit();
    expect(owner.allowsDetailed(oldOn), isTrue);
    final off = owner.acceptContentIntent(false, expectedGeneration: 0);
    expect(owner.allowsDetailed(oldOn), isFalse);
    owner.confirmContentIntent(off, committedEnabled: false);
    expect(owner.allowsDetailed(oldOn), isFalse);
    final on = owner.acceptContentIntent(true, expectedGeneration: 0);
    owner.confirmContentIntent(on, committedEnabled: true);
    expect(owner.allowsDetailed(on), isTrue);
    expect(owner.allowsDetailed(oldOn), isFalse);
    expect(owner.allowsDetailed(off), isFalse);
  });

  test(
    'failed OFF ON readback retains hold; new generation drops unsaved intent',
    () async {
      final gate = LocalDataOperationGate();
      final owner = AlarmOperationCoordinator(gate);
      addTearDown(owner.dispose);
      addTearDown(gate.dispose);
      final off = owner.acceptContentIntent(false, expectedGeneration: 0);
      owner.confirmContentIntent(off, committedEnabled: true);
      expect(owner.allowsDetailed(owner.captureContentPermit()), isFalse);
      await gate.run(() async {}, replacesData: true);
      expect(owner.allowsDetailed(owner.captureContentPermit()), isTrue);
      expect(owner.allowsDetailed(off), isFalse);
    },
  );

  test(
    'OFF accepted after settings snapshot prevents detailed provider send',
    () async {
      final rig = fixtures.Rig();
      addTearDown(rig.dispose);
      rig.repository.settings = const AlarmSettings(
        alarmsEnabled: true,
        detailedNotificationContent: true,
      );
      rig.repository.schedules = [rig.schedule('old-on')];
      rig.repository.block(1);
      final pass = rig.reconcile();
      await rig.repository.snapshots[1]!.future;
      final off = rig.operations.acceptContentIntent(
        false,
        expectedGeneration: 0,
      );
      rig.repository.settings = const AlarmSettings(alarmsEnabled: true);
      rig.operations.confirmContentIntent(off, committedEnabled: false);
      rig.repository.releases[1]!.complete();
      final result = await pass;
      expect(rig.fallback.scheduledFallback, isEmpty);
      expect(
        result.failures.map((failure) => failure.reason),
        contains(AlarmFailureReason.contentDeferred),
      );
      await rig.reconcile();
      expect(
        rig.fallback.scheduledFallback.single.deliveryContent.detailed,
        isFalse,
      );
    },
  );

  test(
    'privacy hold preserves valid private registration against detailed replacement',
    () async {
      final rig = fixtures.Rig();
      addTearDown(rig.dispose);
      rig.repository.schedules = [rig.schedule('private')];
      await rig.reconcile();
      final count = rig.fallback.scheduledFallback.length;
      rig.repository.settings = const AlarmSettings(
        alarmsEnabled: true,
        detailedNotificationContent: true,
      );
      rig.operations.acceptContentIntent(false, expectedGeneration: 0);
      final result = await rig.reconcile();
      expect(rig.fallback.canceledFallback, isEmpty);
      expect(rig.fallback.scheduledFallback.length, count);
      expect(rig.registry.records.single.deliveryContent.detailed, isFalse);
      expect(result.status, AlarmReconciliationStatus.partial);
      expect(result.armedScheduleIds, isEmpty);
    },
  );

  test(
    'hold does not prevent current private scheduling or unrelated cleanup',
    () async {
      final rig = fixtures.Rig();
      addTearDown(rig.dispose);
      rig.repository.schedules = [rig.schedule('old')];
      await rig.reconcile();
      rig.operations.acceptContentIntent(false, expectedGeneration: 0);
      rig.repository.schedules = [rig.schedule('private-new')];
      await rig.reconcile();
      expect(
        rig.fallback.canceledFallback.map((record) => record.scheduleId),
        contains('old'),
      );
      expect(rig.registry.records.single.scheduleId, 'private-new');
      expect(rig.registry.records.single.deliveryContent.detailed, isFalse);
    },
  );
}
