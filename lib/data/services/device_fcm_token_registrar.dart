import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/services/notification_token_registrar.dart';
import 'package:on_time_front/data/data_sources/notification_remote_data_source.dart';
import 'package:on_time_front/data/models/fcm_token_register_request_model.dart';
import 'package:on_time_front/domain/repositories/alarm_repository.dart';

@Singleton(as: FcmTokenRegistrar)
class DeviceFcmTokenRegistrar implements FcmTokenRegistrar {
  DeviceFcmTokenRegistrar(
    this._alarmRepository,
    this._notificationRemoteDataSource,
  );

  final AlarmRepository _alarmRepository;
  final NotificationRemoteDataSource _notificationRemoteDataSource;

  @override
  Future<void> registerToken(String firebaseToken) async {
    final deviceId = await _alarmRepository.getDeviceId();
    await _notificationRemoteDataSource.fcmTokenRegister(
      FcmTokenRegisterRequestModel(
        firebaseToken: firebaseToken,
        deviceId: deviceId,
      ),
    );
  }
}
