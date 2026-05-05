import 'package:json_annotation/json_annotation.dart';

part 'fcm_token_register_request_model.g.dart';

@JsonSerializable()
class FcmTokenRegisterRequestModel {
  final String firebaseToken;
  final String? deviceId;

  FcmTokenRegisterRequestModel({
    required this.firebaseToken,
    this.deviceId,
  });

  factory FcmTokenRegisterRequestModel.fromJson(Map<String, dynamic> json) =>
      _$FcmTokenRegisterRequestModelFromJson(json);
  Map<String, dynamic> toJson() => _$FcmTokenRegisterRequestModelToJson(this);
}
