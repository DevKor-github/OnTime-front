import 'package:freezed_annotation/freezed_annotation.dart';

part 'sign_in_with_google_request_model.g.dart';

@JsonSerializable()
class SignInWithGoogleRequestModel {
  final String idToken;
  final String refreshToken;

  SignInWithGoogleRequestModel({
    required this.idToken,
    required this.refreshToken,
  });

  factory SignInWithGoogleRequestModel.fromJson(Map<String, dynamic> json) =>
      _$SignInWithGoogleRequestModelFromJson(json);

  Map<String, dynamic> toJson() => _$SignInWithGoogleRequestModelToJson(this);
}
