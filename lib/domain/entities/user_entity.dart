import '/core/database/database.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_entity.freezed.dart';

@freezed
class UserEntity with _$UserEntity {
  const UserEntity._();

  const factory UserEntity({
    required String id,
    required String email,
    required String name,
    required Duration spareTime,
    required String note,
    required double score,
    @Default(false) bool isOnboardingCompleted,
  }) = _UserEntity;

  const factory UserEntity.empty() = _UserEntityEmpty;

  static UserEntity fromModel(User user) {
    return UserEntity(
      id: user.id,
      email: user.email,
      name: user.name,
      spareTime: Duration(minutes: user.spareTime),
      note: user.note,
      score: user.score,
    );
  }

  UserEntity? get valueOrNull => switch (this) {
    _UserEntity() => this,
    _UserEntityEmpty() => null,
    _ => null,
  };

  Duration? get spareTimeOrNull => switch (this) {
    _UserEntity(:final spareTime) => spareTime,
    _UserEntityEmpty() => null,
    _ => null,
  };

  double? get scoreOrNull => switch (this) {
    _UserEntity(:final score) => score,
    _UserEntityEmpty() => null,
    _ => null,
  };

  String? get nameOrNull => switch (this) {
    _UserEntity(:final name) => name,
    _UserEntityEmpty() => null,
    _ => null,
  };

  String? get emailOrNull => switch (this) {
    _UserEntity(:final email) => email,
    _UserEntityEmpty() => null,
    _ => null,
  };

  User toModel() {
    return map(
      (userEntity) => User(
        id: userEntity.id,
        email: userEntity.email,
        name: userEntity.name,
        spareTime: userEntity.spareTime.inMinutes,
        note: userEntity.note,
        score: userEntity.score,
      ),
      empty: (_) => throw Exception('Cannot convert empty UserEntity to User'),
    );
  }
}
