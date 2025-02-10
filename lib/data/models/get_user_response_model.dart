import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';

part 'get_user_response_model.g.dart';

@JsonSerializable()
class GetUserResponseModel {
  final int userId;
  final String email;
  final String name;
  final int? spareTime;
  final String? note;
  final double? punctualityScore;
  final String? role;

  const GetUserResponseModel({
    required this.userId,
    required this.email,
    required this.name,
    required this.spareTime,
    required this.punctualityScore,
    this.role,
    this.note,
  });

  UserEntity toEntity() {
    return UserEntity(
      id: userId.toString(),
      email: email,
      name: name,
      spareTime: Duration(minutes: spareTime ?? 0),
      score: punctualityScore ?? -1,
      isOnboardingCompleted: role == 'GUEST' ? false : true,
      note: note ?? '',
    );
  }

  factory GetUserResponseModel.fromJson(Map<String, dynamic> json) =>
      _$GetUserResponseModelFromJson(json);

  Map<String, dynamic> toJson() => _$GetUserResponseModelToJson(this);
}
