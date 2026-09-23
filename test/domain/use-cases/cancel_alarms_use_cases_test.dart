import 'package:on_time_front/core/services/alarm_operation_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/services/alarm_scheduler_service.dart';
import 'package:on_time_front/core/services/fallback_alarm_notification_service.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/repositories/alarm_registry_repository.dart';
import 'package:on_time_front/domain/use-cases/cancel_all_alarms_use_case.dart';
import 'package:on_time_front/domain/use-cases/cancel_schedule_alarm_use_case.dart';

void main() {
  test(
    'CancelScheduleAlarmUseCase cancels matching native and fallback records',
    () async {
      final registry = _FakeAlarmRegistryRepository([
        _record('schedule-1', AlarmProvider.androidAlarmManager),
        _record('schedule-1', AlarmProvider.localNotification),
        _record('schedule-2', AlarmProvider.androidAlarmManager),
        _record('schedule-1', AlarmProvider.none),
      ]);
      final scheduler = _FakeAlarmSchedulerService();
      final fallback = _FakeFallbackAlarmNotificationService();
      final useCase = CancelScheduleAlarmUseCase(registry, scheduler, fallback);

      await useCase('schedule-1');

      expect(scheduler.canceledNative.map((record) => record.scheduleId), [
        'schedule-1',
      ]);
      expect(fallback.canceledFallback.map((record) => record.scheduleId), [
        'schedule-1',
      ]);
      expect(registry.records.map((r) => r.scheduleId), ['schedule-2']);
    },
  );

  test(
    'CancelScheduleAlarmUseCase preserves retry ownership when cancellation fails',
    () async {
      final registry = _FakeAlarmRegistryRepository([
        _record('schedule-1', AlarmProvider.androidAlarmManager),
      ]);
      final scheduler = _FakeAlarmSchedulerService()..throwOnCancel = true;
      final useCase = CancelScheduleAlarmUseCase(
        registry,
        scheduler,
        _FakeFallbackAlarmNotificationService(),
      );

      await expectLater(
        useCase('schedule-1'),
        throwsA(isA<AlarmCleanupIncomplete>()),
      );

      expect(registry.records.single.scheduleId, 'schedule-1');
      expect(registry.records.single.cancellationPending, isTrue);
    },
  );

  test(
    'CancelAllAlarmsUseCase cancels local alarms and clears the registry',
    () async {
      final registry = _FakeAlarmRegistryRepository([
        _record('native', AlarmProvider.androidAlarmManager),
        _record('fallback', AlarmProvider.localNotification),
        _record('none', AlarmProvider.none),
      ]);
      final scheduler = _FakeAlarmSchedulerService();
      final fallback = _FakeFallbackAlarmNotificationService();
      final useCase = CancelAllAlarmsUseCase(registry, scheduler, fallback);

      await useCase();

      expect(scheduler.canceledNative.map((record) => record.scheduleId), [
        'native',
      ]);
      expect(fallback.canceledFallback.map((record) => record.scheduleId), [
        'fallback',
      ]);
      expect(registry.records, isEmpty);
    },
  );

  test('CancelAllAlarmsUseCase clears an empty local registry', () async {
    final registry = _FakeAlarmRegistryRepository(const []);
    final useCase = CancelAllAlarmsUseCase(
      registry,
      _FakeAlarmSchedulerService(),
      _FakeFallbackAlarmNotificationService(),
    );

    await useCase();

    expect(registry.records, isEmpty);
  });
}

ScheduledAlarmRecord _record(String scheduleId, AlarmProvider provider) {
  return ScheduledAlarmRecord(
    scheduleId: scheduleId,
    alarmTime: DateTime(2026, 5, 15, 8),
    preparationStartTime: DateTime(2026, 5, 15, 8, 5),
    scheduleFingerprint: 'fingerprint-$scheduleId',
    provider: provider,
    scheduleTitle: scheduleId,
    payload: {'type': 'schedule_alarm', 'scheduleId': scheduleId},
  );
}

class _FakeAlarmRegistryRepository implements AlarmRegistryRepository {
  _FakeAlarmRegistryRepository(this.records);

  List<ScheduledAlarmRecord> records;
  final deletedScheduleIds = <String>[];
  int deleteAllCount = 0;

  @override
  Future<List<ScheduledAlarmRecord>> loadAll() async => records;

  @override
  Future<void> deleteByScheduleId(String scheduleId) async {
    deletedScheduleIds.add(scheduleId);
  }

  @override
  Future<void> deleteAll() async {
    deleteAllCount += 1;
  }

  @override
  Future<void> replaceAll(List<ScheduledAlarmRecord> next) async {
    records = List.of(next);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAlarmSchedulerService implements AlarmSchedulerService {
  final canceledNative = <ScheduledAlarmRecord>[];
  bool throwOnCancel = false;

  @override
  Future<void> cancelNativeAlarm(ScheduledAlarmRecord record) async {
    if (throwOnCancel) {
      throw Exception('native failure');
    }
    canceledNative.add(record);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFallbackAlarmNotificationService
    implements FallbackAlarmNotificationService {
  final canceledFallback = <ScheduledAlarmRecord>[];

  @override
  Future<void> cancelFallbackAlarm(ScheduledAlarmRecord record) async {
    canceledFallback.add(record);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
