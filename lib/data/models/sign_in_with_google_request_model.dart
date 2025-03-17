import 'package:freezed_annotation/freezed_annotation.dart';

part 'sign_in_with_google_request_model.g.dart';

@JsonSerializable()
class SignInWithGoogleRequestModel {
  final String idToken;

  SignInWithGoogleRequestModel({
    required this.idToken,
  });

  Map<String, dynamic> toJson() {
    return {
      'idToken': idToken,
      'refreshToken': '',
    };
  }
}
