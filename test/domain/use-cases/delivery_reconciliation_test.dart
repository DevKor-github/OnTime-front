import 'package:on_time_front/core/services/alarm_ownership_journal.dart';
import 'package:on_time_front/core/services/alarm_operation_coordinator.dart';
import '../../helpers/isolated_alarm_owner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/entities/delivery_observation.dart';
import 'package:on_time_front/domain/use-cases/reconcile_alarms_use_case.dart';

import 'reconcile_alarms_use_case_test.dart'
    show
        FakeAlarmRepository,
        FakeAlarmRegistryRepository,
        FakeAlarmSchedulerService,
        FakeFallbackAlarmNotificationService,
        scheduleWithAlarmAt;

void main() {
  late AlarmOperationCoordinator isolatedOwner;
  setUp(() {
    isolatedOwner = isolatedAlarmOwner();
  });
  final now = DateTime(2026, 5, 5, 9);
  late FakeAlarmRepository schedules;
  late FakeAlarmRegistryRepository registry;
  late FakeAlarmSchedulerService native;
  late FakeFallbackAlarmNotificationService notifications;
  late ReconcileAlarmsUseCase reconcile;

  setUp(() {
    schedules = FakeAlarmRepository();
    registry = FakeAlarmRegistryRepository();
    native = FakeAlarmSchedulerService()
      ..capabilities = const AlarmSchedulerCapabilities(
        supportsNativeAlarm: true,
        nativeAlarmProvider: AlarmProvider.iosAlarmKit,
        fallbackProvider: AlarmProvider.localNotification,
      );
    notifications = FakeFallbackAlarmNotificationService()
      ..permission = AlarmPermissionState.granted;
    schedules.schedules = [
      scheduleWithAlarmAt(
        id: 'one',
        alarmTime: now.add(const Duration(hours: 1)),
      ),
    ];
    reconcile = ReconcileAlarmsUseCase.test(
      schedules,
      registry,
      native,
      notifications,
      nowProvider: () => now,
      languageCodeProvider: () => 'en',
      timeZoneProvider: () async => 'UTC',

      operations: isolatedOwner,
    );
  });

  for (final enabled in [true, false]) {
    test(
      'lost ownership is not reported as armed or disabled: enabled=$enabled',
      () async {
        schedules.settings = AlarmSettings(alarmsEnabled: enabled);
        await isolatedOwner.journal.save(
          AlarmJournalSnapshot(unknownOwnership: true),
        );
        final result = await reconcile();
        expect(result.status, AlarmReconciliationStatus.partial);
        expect(result.armedScheduleIds, isEmpty);
        expect(result.failures, isNotEmpty);
        expect(native.scheduledNative, isEmpty);
        expect(notifications.scheduledFallback, isEmpty);
        expect((await isolatedOwner.journal.read()).unknownOwnership, true);
      },
    );
  }

  test(
    'write-ahead identity precedes native scheduling and a now-expired target is not replayed',
    () async {
      var clock = now;
      var sawIntent = false;
      registry.onReplace = (records) {
        if (records.isNotEmpty) {
          expect(native.scheduledNative, isEmpty);
          expect(records.single.cancellationPending, true);
          sawIntent = true;
          clock = now.add(const Duration(hours: 2));
        }
      };
      final delayed = ReconcileAlarmsUseCase.test(
        schedules,
        registry,
        native,
        notifications,
        nowProvider: () => clock,
        languageCodeProvider: () => 'en',
        timeZoneProvider: () async => 'UTC',

        operations: isolatedOwner,
      );
      final result = await delayed();
      expect(sawIntent, true);
      expect(native.scheduledNative, isEmpty);
      expect(notifications.scheduledFallback, isEmpty);
      expect(result.armedScheduleIds, isEmpty);
      expect(registry.records, isEmpty);
    },
  );

  test(
    'Android reapplication preserves an existing owned platform ID',
    () async {
      native.capabilities = const AlarmSchedulerCapabilities(
        supportsNativeAlarm: false,
        nativeAlarmProvider: AlarmProvider.none,
        fallbackProvider: AlarmProvider.localNotification,
      );
      notifications.timingPermission = AlarmPermissionState.granted;
      await reconcile();
      final previous = registry.records.single;
      registry.records = [previous.copyWith(fallbackNotificationId: 99)];
      // Seed migrated ownership consistently in both persistence projections.
      await isolatedOwner.journal.confirmedCancelled(previous);
      await isolatedOwner.journal.remember(registry.records, pending: false);
      notifications.pendingFallback
        ..clear()
        ..['99'] = const PendingDelivery(id: '99', scheduleId: 'one');
      expect((await reconcile()).armedScheduleIds, ['one']);
      expect(notifications.pendingFallback.keys, ['99']);
      expect(registry.records.single.fallbackNotificationId, 99);
      expect(notifications.canceledFallback, isEmpty);
    },
  );

  test(
    'a registry-owned ID with a conflicting route is cancelled before repair',
    () async {
      native.nativePermission = AlarmPermissionState.denied;
      await reconcile();
      final id = '${registry.records.single.fallbackNotificationId}';
      notifications.pendingFallback[id] = PendingDelivery(
        id: id,
        scheduleId: 'another',
      );
      expect((await reconcile()).armedScheduleIds, ['one']);
      expect(notifications.canceledFallback.single.scheduleId, 'one');
      expect(notifications.scheduledFallback, hasLength(2));
      expect(notifications.pendingFallback[id]!.scheduleId, 'one');
    },
  );

  for (final enabled in [true, false]) {
    for (final unknownOwnership in [false, true]) {
      test(
        'empty registry with native ${unknownOwnership ? 'unmapped ID' : 'query failure'} stays incomplete enabled=$enabled',
        () async {
          schedules.settings = AlarmSettings(alarmsEnabled: enabled);
          schedules.schedules = [];
          native.nativeObservationFails = !unknownOwnership;
          native.unmappedNativeCount = unknownOwnership ? 1 : 0;
          final result = await reconcile();
          expect(result.status, AlarmReconciliationStatus.partial);
          expect(result.armedScheduleIds, isEmpty);
          expect(result.failures, isNotEmpty);
          expect(native.canceledNative, isEmpty);
          expect(registry.records, isEmpty);
        },
      );
    }
  }

  test(
    'native revoke and grant switch providers after cancelling the old registration',
    () async {
      await reconcile();
      expect(registry.records.single.provider, AlarmProvider.iosAlarmKit);
      native.nativePermission = AlarmPermissionState.denied;
      await reconcile();
      expect(native.pendingNative, isEmpty);
      expect(notifications.pendingFallback, hasLength(1));
      expect(registry.records.single.provider, AlarmProvider.localNotification);
      native.nativePermission = AlarmPermissionState.granted;
      await reconcile();
      expect(notifications.pendingFallback, isEmpty);
      expect(native.pendingNative, {'one'});
      expect(registry.records.single.provider, AlarmProvider.iosAlarmKit);
    },
  );

  test(
    'unconfirmed provider cancellation blocks duplicate fallback, then retry converges',
    () async {
      await reconcile();
      native.nativePermission = AlarmPermissionState.denied;
      native.throwOnCancelIds.add('one');
      final failed = await reconcile();
      expect(failed.status, AlarmReconciliationStatus.partial);
      expect(failed.armedScheduleIds, isEmpty);
      expect(registry.records.single.cancellationPending, true);
      expect(notifications.scheduledFallback, isEmpty);
      native.throwOnCancelIds.clear();
      expect((await reconcile()).armedScheduleIds, ['one']);
      expect(registry.records.single.provider, AlarmProvider.localNotification);
      expect(registry.records.single.cancellationPending, false);
    },
  );

  test(
    'OS pending loss repairs a future native reservation but never replays an elapsed one',
    () async {
      await reconcile();
      native.pendingNative.clear();
      expect((await reconcile()).armedScheduleIds, ['one']);
      expect(native.scheduledNative, hasLength(2));
      schedules.schedules = [
        scheduleWithAlarmAt(
          id: 'one',
          alarmTime: now.subtract(const Duration(minutes: 1)),
        ),
      ];
      await reconcile();
      expect(native.pendingNative, isEmpty);
      expect(native.scheduledNative, hasLength(2));
    },
  );

  test(
    'native query unknown retains ownership without treating absence or claiming success',
    () async {
      await reconcile();
      native.nativeObservationFails = true;
      final result = await reconcile();
      expect(result.status, AlarmReconciliationStatus.partial);
      expect(result.armedScheduleIds, isEmpty);
      expect(registry.records.single.scheduleId, 'one');
      expect(native.scheduledNative, hasLength(1));
      expect(native.canceledNative, isEmpty);
    },
  );

  test(
    'iOS notification OS loss repairs while successful query allows keeping the request',
    () async {
      native.nativePermission = AlarmPermissionState.denied;
      await reconcile();
      await reconcile();
      expect(notifications.scheduledFallback, hasLength(1));
      notifications.pendingFallback.clear();
      await reconcile();
      expect(notifications.scheduledFallback, hasLength(2));
    },
  );

  test(
    'Android cache presence causes same-ID reapplication rather than an OS survival claim',
    () async {
      native.capabilities = const AlarmSchedulerCapabilities(
        supportsNativeAlarm: false,
        nativeAlarmProvider: AlarmProvider.none,
        fallbackProvider: AlarmProvider.localNotification,
      );
      notifications.timingPermission = AlarmPermissionState.granted;
      await reconcile();
      await reconcile();
      expect(notifications.scheduledFallback, hasLength(2));
      expect(
        notifications.scheduledFallback
            .map((r) => r.fallbackNotificationId)
            .toSet(),
        {stableAlarmId('one')},
      );
      expect(notifications.canceledFallback, isEmpty);
      expect(notifications.pendingFallback, hasLength(1));
      expect(
        registry.records.single.notificationTiming,
        NotificationTiming.exact,
      );
    },
  );

  test(
    'failed post-schedule verification preserves ownership but excludes armed success',
    () async {
      native.nativePermission = AlarmPermissionState.denied;
      notifications.forgetScheduled = true;
      final result = await reconcile();
      expect(result.status, AlarmReconciliationStatus.partial);
      expect(result.armedScheduleIds, isEmpty);
      expect(registry.records.single.scheduleId, 'one');
      expect(registry.records.single.provider, AlarmProvider.localNotification);
    },
  );

  test(
    'OS query error after startup never becomes a healthy stored notification',
    () async {
      native.nativePermission = AlarmPermissionState.denied;
      await reconcile();
      notifications.observationFails = true;
      final result = await reconcile();
      expect(result.status, AlarmReconciliationStatus.partial);
      expect(result.armedScheduleIds, isEmpty);
      expect(registry.records, hasLength(1));
      expect(notifications.scheduledFallback, hasLength(1));
    },
  );

  test(
    'confirmed fallback orphans are targeted; unrelated and unknown ownership survive',
    () async {
      native.nativePermission = AlarmPermissionState.denied;
      notifications.pendingFallback.addAll({
        '99': const PendingDelivery(id: '99', scheduleId: 'deleted'),
        '100': const PendingDelivery(id: '100'),
      });
      await reconcile();
      expect(notifications.canceledFallback.single.fallbackNotificationId, 99);
      expect(notifications.pendingFallback.keys, contains('100'));
      expect(registry.records.single.scheduleId, 'one');
    },
  );

  test(
    'orphan cancellation failure persists its real platform ID and retries while disabled',
    () async {
      schedules.settings = const AlarmSettings(alarmsEnabled: false);
      notifications.pendingFallback['99'] = const PendingDelivery(
        id: '99',
        scheduleId: 'deleted',
      );
      notifications.throwOnCancelIds.add('deleted');
      expect((await reconcile()).status, AlarmReconciliationStatus.partial);
      expect(registry.records.single.fallbackNotificationId, 99);
      expect(registry.records.single.cancellationPending, true);
      notifications.throwOnCancelIds.clear();
      expect((await reconcile()).status, AlarmReconciliationStatus.disabled);
      expect(registry.records, isEmpty);
    },
  );

  test(
    'native failure uses only the actual fallback receipt after native cleanup',
    () async {
      native.throwOnScheduleIds.add('one');
      expect((await reconcile()).armedScheduleIds, ['one']);
      expect(native.canceledNative.single.scheduleId, 'one');
      expect(registry.records.single.provider, AlarmProvider.localNotification);
      expect(
        registry.records.single.notificationTiming,
        NotificationTiming.platformDefault,
      );
    },
  );

  test(
    'failed native write cleanup forbids fallback and keeps cancellation identity',
    () async {
      native.throwOnScheduleIds.add('one');
      native.throwOnCancelIds.add('one');
      final result = await reconcile();
      expect(result.armedScheduleIds, isEmpty);
      expect(notifications.scheduledFallback, isEmpty);
      expect(registry.records.single.provider, AlarmProvider.iosAlarmKit);
      expect(registry.records.single.cancellationPending, true);
    },
  );
}
