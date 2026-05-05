import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';

abstract interface class AlarmRepository {
  Future<String> getDeviceId();

  Future<AlarmDeviceInfo> buildCurrentDeviceInfo();

  Future<AlarmSettings> getAlarmSettings();

  Future<AlarmSettings> updateAlarmSettings({required bool alarmsEnabled});

  Future<void> registerCurrentDevice(AlarmDeviceInfo deviceInfo);

  Future<void> unregisterCurrentDevice(String deviceId);

  Future<List<ScheduleWithPreparationEntity>> getAlarmWindow(
    DateTime startDate,
    DateTime endDate,
  );

  Future<void> postAlarmStatus(AlarmStatusReport report);
}
