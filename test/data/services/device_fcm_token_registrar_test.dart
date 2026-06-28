import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/data/data_sources/notification_remote_data_source.dart';
import 'package:on_time_front/data/models/fcm_token_register_request_model.dart';
import 'package:on_time_front/data/services/device_fcm_token_registrar.dart';
import 'package:on_time_front/domain/repositories/alarm_repository.dart';

void main() {
  test('registers FCM token for the current alarm device', () async {
    final alarmRepository = _FakeAlarmRepository(deviceId: 'device-1');
    final remoteDataSource = _FakeNotificationRemoteDataSource();
    final registrar = DeviceFcmTokenRegistrar(
      alarmRepository,
      remoteDataSource,
    );

    await registrar.registerToken('fcm-token');

    expect(remoteDataSource.registeredTokens.single.firebaseToken, 'fcm-token');
    expect(remoteDataSource.registeredTokens.single.deviceId, 'device-1');
  });
}

class _FakeAlarmRepository implements AlarmRepository {
  _FakeAlarmRepository({required this.deviceId});

  final String deviceId;

  @override
  Future<String> getDeviceId() async => deviceId;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeNotificationRemoteDataSource
    implements NotificationRemoteDataSource {
  final registeredTokens = <FcmTokenRegisterRequestModel>[];

  @override
  Future<void> fcmTokenRegister(FcmTokenRegisterRequestModel model) async {
    registeredTokens.add(model);
  }
}
