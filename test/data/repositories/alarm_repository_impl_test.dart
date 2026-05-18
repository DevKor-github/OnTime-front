import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/services/alarm_scheduler_service.dart';
import 'package:on_time_front/data/data_sources/alarm_remote_data_source.dart';
import 'package:on_time_front/data/repositories/alarm_repository_impl.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late _FakeAlarmRemoteDataSource remoteDataSource;
  late _FakeAlarmSchedulerService schedulerService;
  late AlarmRepositoryImpl repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    remoteDataSource = _FakeAlarmRemoteDataSource();
    schedulerService = _FakeAlarmSchedulerService();
    repository = AlarmRepositoryImpl(
      remoteDataSource: remoteDataSource,
      schedulerService: schedulerService,
    );
  });

  test('getDeviceId reuses a valid stored device id', () async {
    SharedPreferences.setMockInitialValues({
      'alarm_device_id': '123e4567-e89b-12d3-a456-426614174000',
    });

    expect(
      await repository.getDeviceId(),
      '123e4567-e89b-12d3-a456-426614174000',
    );
  });

  test(
    'getDeviceId replaces an invalid stored device id with a UUID',
    () async {
      SharedPreferences.setMockInitialValues({'alarm_device_id': 'bad'});

      final deviceId = await repository.getDeviceId();

      expect(deviceId, isNot('bad'));
      expect(deviceId, matches(RegExp(r'^[0-9a-f-]{36}$')));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('alarm_device_id'), deviceId);
    },
  );

  test(
    'buildCurrentDeviceInfo combines persisted id and scheduler capabilities',
    () async {
      SharedPreferences.setMockInitialValues({
        'alarm_device_id': '123e4567-e89b-12d3-a456-426614174000',
      });
      schedulerService.capabilities = const AlarmSchedulerCapabilities(
        supportsNativeAlarm: true,
        nativeAlarmProvider: AlarmProvider.androidAlarmManager,
        fallbackProvider: AlarmProvider.localNotification,
      );

      final info = await repository.buildCurrentDeviceInfo();

      expect(info.deviceId, '123e4567-e89b-12d3-a456-426614174000');
      expect(info.appVersion, '1.0.0');
      expect(info.supportsNativeAlarm, isTrue);
      expect(info.nativeAlarmProvider, AlarmProvider.androidAlarmManager);
      expect(info.fallbackProvider, AlarmProvider.localNotification);
      expect(info.platform, isNotEmpty);
      expect(info.osVersion, isNotEmpty);
    },
  );

  test('alarm settings calls delegate to the remote data source', () async {
    remoteDataSource.settings = const AlarmSettings(
      alarmsEnabled: false,
      defaultAlarmOffsetMinutes: 10,
    );

    expect(await repository.getAlarmSettings(), remoteDataSource.settings);
    expect(
      await repository.updateAlarmSettings(alarmsEnabled: true),
      const AlarmSettings(alarmsEnabled: true),
    );
    expect(remoteDataSource.updatedValues, [true]);
  });

  test('device, window, and status calls forward their payloads', () async {
    const deviceInfo = AlarmDeviceInfo(
      deviceId: 'device-1',
      platform: 'android',
      appVersion: '1.0.0',
      osVersion: 'android',
      supportsNativeAlarm: true,
      nativeAlarmProvider: AlarmProvider.androidAlarmManager,
      fallbackProvider: AlarmProvider.localNotification,
    );
    final start = DateTime(2026, 5, 15);
    final end = DateTime(2026, 5, 16);
    final report = _alarmStatusReport();

    await repository.registerCurrentDevice(deviceInfo);
    await repository.unregisterCurrentDevice('device-1');
    expect(await repository.getAlarmWindow(start, end), isEmpty);
    await repository.postAlarmStatus(report);

    expect(remoteDataSource.registeredDevices, [deviceInfo]);
    expect(remoteDataSource.unregisteredDeviceIds, ['device-1']);
    expect(remoteDataSource.alarmWindowRanges, [(start, end)]);
    expect(remoteDataSource.statusReports, [report]);
  });
}

AlarmStatusReport _alarmStatusReport() {
  final now = DateTime(2026, 5, 15, 9);
  return AlarmStatusReport(
    deviceId: 'device-1',
    reconciledAt: now,
    scheduleWindowStart: now,
    scheduleWindowEnd: now.add(const Duration(days: 1)),
    alarmCoverageStart: now,
    alarmCoverageEnd: now.add(const Duration(hours: 1)),
    status: AlarmReconciliationStatus.armed,
    nativeAlarmProvider: AlarmProvider.androidAlarmManager,
    fallbackProvider: AlarmProvider.localNotification,
    armedScheduleCount: 1,
    armedScheduleIds: const ['schedule-1'],
    skippedScheduleCount: 0,
    failures: const [],
  );
}

class _FakeAlarmSchedulerService extends AlarmSchedulerService {
  AlarmSchedulerCapabilities capabilities =
      AlarmSchedulerCapabilities.unsupported;

  @override
  Future<AlarmSchedulerCapabilities> getCapabilities() async => capabilities;
}

class _FakeAlarmRemoteDataSource implements AlarmRemoteDataSource {
  AlarmSettings settings = const AlarmSettings(alarmsEnabled: true);
  final updatedValues = <bool>[];
  final registeredDevices = <AlarmDeviceInfo>[];
  final unregisteredDeviceIds = <String>[];
  final alarmWindowRanges = <(DateTime, DateTime)>[];
  final statusReports = <AlarmStatusReport>[];

  @override
  Future<AlarmSettings> getAlarmSettings() async => settings;

  @override
  Future<AlarmSettings> updateAlarmSettings({
    required bool alarmsEnabled,
  }) async {
    updatedValues.add(alarmsEnabled);
    return AlarmSettings(alarmsEnabled: alarmsEnabled);
  }

  @override
  Future<void> registerCurrentDevice(AlarmDeviceInfo deviceInfo) async {
    registeredDevices.add(deviceInfo);
  }

  @override
  Future<void> unregisterCurrentDevice(String deviceId) async {
    unregisteredDeviceIds.add(deviceId);
  }

  @override
  Future<List<ScheduleWithPreparationEntity>> getAlarmWindow(
    DateTime startDate,
    DateTime endDate,
  ) async {
    alarmWindowRanges.add((startDate, endDate));
    return const [];
  }

  @override
  Future<void> postAlarmStatus(AlarmStatusReport report) async {
    statusReports.add(report);
  }
}
