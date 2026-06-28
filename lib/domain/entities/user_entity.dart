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
}
