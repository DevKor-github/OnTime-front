import 'package:on_time_front/domain/entities/user_entity.dart';

abstract interface class UserRepository {
  Stream<UserEntity> get userStream;

  Future<UserEntity> getUser();

  Future<void> saveUser(UserEntity user);

  Future<void> resetLocalData();
}
