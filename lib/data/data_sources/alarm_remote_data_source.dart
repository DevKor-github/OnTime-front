import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/constants/endpoint.dart';
import 'package:on_time_front/data/models/alarm_device_model.dart';
import 'package:on_time_front/data/models/alarm_settings_model.dart';
import 'package:on_time_front/data/models/alarm_status_report_model.dart';
import 'package:on_time_front/data/models/alarm_window_schedule_model.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';

abstract interface class AlarmRemoteDataSource {
  Future<AlarmSettings> getAlarmSettings();

  Future<AlarmSettings> updateAlarmSettings({
    required bool alarmsEnabled,
  });

  Future<void> registerCurrentDevice(AlarmDeviceInfo deviceInfo);

  Future<void> unregisterCurrentDevice(String deviceId);

  Future<List<ScheduleWithPreparationEntity>> getAlarmWindow(
    DateTime startDate,
    DateTime endDate,
  );

  Future<void> postAlarmStatus(AlarmStatusReport report);
}

@Injectable(as: AlarmRemoteDataSource)
class AlarmRemoteDataSourceImpl implements AlarmRemoteDataSource {
  final Dio dio;

  AlarmRemoteDataSourceImpl(this.dio);

  @override
  Future<AlarmSettings> getAlarmSettings() async {
    final result = await dio.get(Endpoint.alarmSettings);
    if (result.statusCode == 200) {
      return AlarmSettingsModel.fromJson(
        result.data['data'] as Map<String, dynamic>,
      ).toEntity();
    }
    throw Exception('Error getting alarm settings');
  }

  @override
  Future<AlarmSettings> updateAlarmSettings({
    required bool alarmsEnabled,
  }) async {
    final result = await dio.patch(
      Endpoint.alarmSettings,
      data: UpdateAlarmSettingsRequestModel(
        alarmsEnabled: alarmsEnabled,
      ).toJson(),
    );
    if (result.statusCode == 200) {
      return AlarmSettingsModel.fromJson(
        result.data['data'] as Map<String, dynamic>,
      ).toEntity();
    }
    throw Exception('Error updating alarm settings');
  }

  @override
  Future<void> registerCurrentDevice(AlarmDeviceInfo deviceInfo) async {
    final result = await dio.put(
      Endpoint.currentDevice,
      data: AlarmDeviceInfoModel.fromEntity(deviceInfo).toJson(),
    );
    if (result.statusCode != 200) {
      throw Exception('Error registering current device');
    }
  }

  @override
  Future<void> unregisterCurrentDevice(String deviceId) async {
    final result = await dio.delete(
      Endpoint.currentDevice,
      data: {'deviceId': deviceId},
    );
    if (result.statusCode != 200) {
      throw Exception('Error unregistering current device');
    }
  }

  @override
  Future<List<ScheduleWithPreparationEntity>> getAlarmWindow(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final result = await dio.get(
      Endpoint.alarmWindow,
      queryParameters: {
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
      },
    );
    if (result.statusCode == 200) {
      return (result.data['data'] as List<dynamic>)
          .map(
            (item) => AlarmWindowScheduleModel.fromJson(
              item as Map<String, dynamic>,
            ).toEntity(),
          )
          .toList();
    }
    throw Exception('Error getting alarm window');
  }

  @override
  Future<void> postAlarmStatus(AlarmStatusReport report) async {
    try {
      final model = AlarmStatusReportModel(report);
      var result = await _postAlarmStatus(model.toJson());
      if (result.statusCode == 400 && _responseCode(result.data) == '400') {
        result = await _postAlarmStatus(
          model.toJson(wireFormat: AlarmStatusReportWireFormat.lowerCamel),
        );
      }
      if (result.statusCode == 409 &&
          _errorCode(result.data) == 'DEVICE_SESSION_NOT_ACTIVE') {
        throw const DeviceSessionNotActiveException();
      }
      if (result.statusCode != 200) {
        throw Exception('Error posting alarm status: ${result.statusCode}');
      }
    } on DioException catch (error) {
      if (error.response?.statusCode == 409 &&
          _errorCode(error.response?.data) == 'DEVICE_SESSION_NOT_ACTIVE') {
        throw const DeviceSessionNotActiveException();
      }
      rethrow;
    }
  }

  Future<Response<dynamic>> _postAlarmStatus(Map<String, dynamic> data) {
    return dio.post(
      Endpoint.alarmStatus,
      data: data,
      options: Options(
        validateStatus: (status) => status != null && status < 500,
      ),
    );
  }

  String? _errorCode(Object? data) {
    if (data is Map<String, dynamic>) {
      final error = data['error'];
      final code = _responseCode(data);
      if (code != null) {
        return code;
      }
      if (error is Map<String, dynamic> && error['code'] is String) {
        return error['code'] as String;
      }
    }
    return null;
  }

  String? _responseCode(Object? data) {
    if (data is Map<String, dynamic>) {
      final code = data['code'];
      if (code is String) return code;
      if (code is num) return code.toInt().toString();
    }
    return null;
  }
}
