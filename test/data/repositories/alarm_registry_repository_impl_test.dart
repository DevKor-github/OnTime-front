import 'package:on_time_front/domain/use-cases/reconcile_alarms_use_case.dart';
import '../../domain/use-cases/reconcile_alarms_use_case_test.dart' as fixtures;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/data/data_sources/alarm_registry_local_data_source.dart';
import 'package:on_time_front/data/repositories/alarm_registry_repository_impl.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FakeAlarmRegistryLocalDataSource localDataSource;
  late AlarmRegistryRepositoryImpl repository;

  setUp(() {
    localDataSource = _FakeAlarmRegistryLocalDataSource();
    repository = AlarmRegistryRepositoryImpl(localDataSource: localDataSource);
  });

  test(
    'real storage retains every failed platform ownership for the same Schedule',
    () async {
      SharedPreferences.setMockInitialValues({});
      final real = AlarmRegistryRepositoryImpl(
        localDataSource: AlarmRegistryLocalDataSourceImpl(),
      );
      final native = _record(
        'same',
      ).copyWith(nativeAlarmId: 7, cancellationPending: true);
      final first = _record('same').copyWith(
        provider: AlarmProvider.localNotification,
        fallbackNotificationId: 11,
        notificationTiming: NotificationTiming.approximate,
        cancellationPending: true,
      );
      final second = first.copyWith(fallbackNotificationId: 12);
      await real.replaceAll([native, first, second]);
      final restored = await real.loadAll();
      expect(
        restored
            .singleWhere((r) => r.fallbackNotificationId == 11)
            .notificationTiming,
        NotificationTiming.approximate,
      );
      expect(restored.map(alarmOwnershipKey).toSet(), {
        'androidAlarmManager:7',
        'localNotification:11',
        'localNotification:12',
      });
      await real.upsert(second);
      expect(
        (await real.loadAll()).map(alarmOwnershipKey).toSet(),
        restored.map(alarmOwnershipKey).toSet(),
      );
      // Different Schedule labels do not make the same actual OS ID two requests.
      await real.upsert(
        _record('different').copyWith(
          provider: AlarmProvider.localNotification,
          fallbackNotificationId: 11,
          cancellationPending: true,
        ),
      );
      final after = await real.loadAll();
      expect(after, hasLength(3));
      expect(
        after.singleWhere((r) => r.fallbackNotificationId == 11).scheduleId,
        'different',
      );
    },
  );

  for (final failDuplicateCancellation in [false, true]) {
    test(
      'real registry preserves duplicate ownership until confirmed cancellation: failure=$failDuplicateCancellation',
      () async {
        SharedPreferences.setMockInitialValues({});
        final real = AlarmRegistryRepositoryImpl(
          localDataSource: AlarmRegistryLocalDataSourceImpl(),
        );
        final now = DateTime.utc(2026, 9, 24);
        final schedule = fixtures.scheduleWithAlarmAt(
          id: 'same',
          alarmTime: now.add(const Duration(hours: 1)),
        );
        final first = buildScheduledAlarmRecord(
          schedule,
          alarmOffset: const Duration(minutes: 5),
          provider: AlarmProvider.localNotification,
          currentTimeZoneId: 'UTC',
          languageCode: 'en',
        ).copyWith(fallbackNotificationId: 11);
        final second = first.copyWith(fallbackNotificationId: 12);
        final fallback = fixtures.FakeFallbackAlarmNotificationService()
          ..permission = AlarmPermissionState.granted;
        await fallback.scheduleFallbackAlarm(first);
        await fallback.scheduleFallbackAlarm(second);
        await real.replaceAll([first, second]);
        final alarms = fixtures.FakeAlarmRepository()..schedules = [schedule];
        if (failDuplicateCancellation) fallback.throwOnCancelIds.add('same');
        final reconcile = ReconcileAlarmsUseCase.test(
          alarms,
          real,
          fixtures.FakeAlarmSchedulerService(),
          fallback,
          nowProvider: () => now,
          timeZoneProvider: () async => 'UTC',
          languageCodeProvider: () => 'en',
        );
        final result = await reconcile();
        if (failDuplicateCancellation) {
          expect(result.armedScheduleIds, isEmpty);
          expect(result.status, AlarmReconciliationStatus.partial);
          final kept = await real.loadAll();
          expect(kept.map((r) => r.fallbackNotificationId).toSet(), {11, 12});
          expect(
            kept
                .singleWhere((r) => r.fallbackNotificationId == 12)
                .cancellationPending,
            true,
          );
          fallback.throwOnCancelIds.clear();
          expect((await reconcile()).armedScheduleIds, ['same']);
        } else {
          expect(result.armedScheduleIds, ['same']);
        }
        expect((await real.loadAll()).single.fallbackNotificationId, 11);
        expect(fallback.pendingFallback.keys, ['11']);
        expect(fallback.canceledFallback.map((r) => r.fallbackNotificationId), [
          12,
        ]);
      },
    );
  }

  test('loadAll returns the current local registry', () async {
    localDataSource.records = [_record('schedule-1')];

    expect(await repository.loadAll(), [_record('schedule-1')]);
  });

  test(
    'upsert replaces an existing schedule record and keeps others',
    () async {
      localDataSource.records = [
        _record('schedule-1', title: 'Old'),
        _record('schedule-2'),
      ];

      await repository.upsert(_record('schedule-1', title: 'New'));

      expect(localDataSource.records, [
        _record('schedule-2'),
        _record('schedule-1', title: 'New'),
      ]);
    },
  );

  test('deleteByScheduleId removes only the requested schedule', () async {
    localDataSource.records = [_record('schedule-1'), _record('schedule-2')];

    await repository.deleteByScheduleId('schedule-1');

    expect(localDataSource.records, [_record('schedule-2')]);
  });

  test(
    'replaceAll deduplicates actual platform identity and deleteAll clears storage',
    () async {
      await repository.replaceAll([
        _record('schedule-1', title: 'Old'),
        _record('schedule-1', title: 'New'),
        _record('schedule-2'),
      ]);

      expect(localDataSource.records, [
        _record('schedule-1', title: 'New'),
        _record('schedule-2'),
      ]);

      await repository.deleteAll();

      expect(localDataSource.records, isEmpty);
    },
  );
}

ScheduledAlarmRecord _record(String scheduleId, {String title = 'Meeting'}) {
  return ScheduledAlarmRecord(
    scheduleId: scheduleId,
    alarmTime: DateTime(2026, 5, 15, 8),
    preparationStartTime: DateTime(2026, 5, 15, 8, 5),
    scheduleFingerprint: 'fingerprint-$scheduleId',
    provider: AlarmProvider.androidAlarmManager,
    scheduleTitle: title,
    payload: {'type': 'schedule_alarm', 'scheduleId': scheduleId},
  );
}

class _FakeAlarmRegistryLocalDataSource
    implements AlarmRegistryLocalDataSource {
  List<ScheduledAlarmRecord> records = const [];

  @override
  Future<List<ScheduledAlarmRecord>> loadAll() async => records;

  @override
  Future<void> replaceAll(List<ScheduledAlarmRecord> records) async {
    this.records = List.of(records);
  }
}
