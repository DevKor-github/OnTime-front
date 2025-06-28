import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/constants/endpoint.dart';
import 'package:on_time_front/data/models/fcm_token_register_request_model.dart';

abstract interface class NotificationRemoteDataSource {
  Future<void> fcmTokenRegister(FcmTokenRegisterRequestModel model);
}

@Injectable(as: NotificationRemoteDataSource)
class NotificationRemoteDataSourceImpl implements NotificationRemoteDataSource {
  final Dio dio;

  NotificationRemoteDataSourceImpl(this.dio);

  @override
  Future<void> fcmTokenRegister(FcmTokenRegisterRequestModel model) async {
    try {
      final result = await dio.post(
        Endpoint.fcmTokenRegister,
        data: model.toJson(),
      );

      if (result.statusCode != 200) {
        throw Exception('Error registering FCM token');
      }
    } catch (e) {
      rethrow;
    }
  }
}
