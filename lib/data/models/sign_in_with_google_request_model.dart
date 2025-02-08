import 'package:freezed_annotation/freezed_annotation.dart';

part 'sign_in_with_google_request_model.g.dart';

@JsonSerializable()
class SignInWithGoogleRequestModel {
  final String accessToken;

  SignInWithGoogleRequestModel({
    required this.accessToken,
  });

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
    };
  }
}
