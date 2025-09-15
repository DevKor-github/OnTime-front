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

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> map = {
      'idToken': idToken,
      'authCode': authCode,
      'fullName': fullName,
    };
    if (email != null) {
      map['email'] = email;
    }
    return map;
  }
}
