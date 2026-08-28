import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_entity.freezed.dart';

@freezed
class UserEntity with _$UserEntity {
  const UserEntity._();

  const factory UserEntity({
    required String id,
    required Duration spareTime,
    required String note,
    @Default(0) int eligibleOutcomeCount,
    @Default(0) int onTimeOutcomeCount,
    @Default(false) bool isOnboardingCompleted,
  }) = _UserEntity;

  const factory UserEntity.empty() = _UserEntityEmpty;

  UserEntity? get valueOrNull => switch (this) {
    _UserEntity() => this,
    _UserEntityEmpty() => null,
    _ => null,
  };

  String get id => switch (this) {
    _UserEntity(:final id) => id,
    _UserEntityEmpty() => throw StateError('The local profile is empty.'),
    _ => throw StateError('Unknown local profile state.'),
  };

  Duration get spareTime => switch (this) {
    _UserEntity(:final spareTime) => spareTime,
    _UserEntityEmpty() => throw StateError('The local profile is empty.'),
    _ => throw StateError('Unknown local profile state.'),
  };

  String get note => switch (this) {
    _UserEntity(:final note) => note,
    _UserEntityEmpty() => throw StateError('The local profile is empty.'),
    _ => throw StateError('Unknown local profile state.'),
  };

  int get eligibleOutcomeCount => switch (this) {
    _UserEntity(:final eligibleOutcomeCount) => eligibleOutcomeCount,
    _UserEntityEmpty() => throw StateError('The local profile is empty.'),
    _ => throw StateError('Unknown local profile state.'),
  };

  int get onTimeOutcomeCount => switch (this) {
    _UserEntity(:final onTimeOutcomeCount) => onTimeOutcomeCount,
    _UserEntityEmpty() => throw StateError('The local profile is empty.'),
    _ => throw StateError('Unknown local profile state.'),
  };

  bool get isOnboardingCompleted => switch (this) {
    _UserEntity(:final isOnboardingCompleted) => isOnboardingCompleted,
    _UserEntityEmpty() => false,
    _ => false,
  };

  Duration? get spareTimeOrNull => switch (this) {
    _UserEntity(:final spareTime) => spareTime,
    _UserEntityEmpty() => null,
    _ => null,
  };

  double? get scoreOrNull => switch (this) {
    _UserEntity(:final eligibleOutcomeCount, :final onTimeOutcomeCount) =>
      eligibleOutcomeCount == 0
          ? null
          : onTimeOutcomeCount * 100 / eligibleOutcomeCount,
    _UserEntityEmpty() => null,
    _ => null,
  };
}
