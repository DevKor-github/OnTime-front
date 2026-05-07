import 'package:freezed_annotation/freezed_annotation.dart';

part 'sign_in_with_apple_request_model.g.dart';

@JsonSerializable()
class SignInWithAppleRequestModel {
  final String idToken;
  final String authCode;
  final String fullName;
  final String? email;

  SignInWithAppleRequestModel({
    required this.idToken,
    required this.authCode,
    required this.fullName,
    this.email,
  });

  factory SignInWithAppleRequestModel.fromJson(Map<String, dynamic> json) =>
      _$SignInWithAppleRequestModelFromJson(json);

  Map<String, dynamic> toJson() {
    final map = _$SignInWithAppleRequestModelToJson(this);
    map.removeWhere((key, value) => value == null);
    return map;
  }
}
