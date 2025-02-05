import 'package:json_annotation/json_annotation.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';

part 'sign_in_user_response_model.g.dart';

@JsonSerializable()
class SignInUserResponseModel {
  final String id;
  final String email;
  final String name;
  final int spareTime;
  final String? note;
  final double score;
  final String? role;

  const SignInUserResponseModel({
    required this.id,
    required this.email,
    required this.name,
    required this.spareTime,
    required this.score,
    this.role,
    this.note,
  });

  UserEntity toEntity() {
    return UserEntity(
      id: id,
      email: email,
      name: name,
      spareTime: Duration(minutes: spareTime),
      score: score,
      isOnboardingCompleted: role == 'GUEST' ? false : true,
      note: note ?? '',
    );
  }

  factory SignInUserResponseModel.fromJson(Map<String, dynamic> json) =>
      _$SignInUserResponseModelFromJson(json);

  Map<String, dynamic> toJson() => _$SignInUserResponseModelToJson(this);
}
