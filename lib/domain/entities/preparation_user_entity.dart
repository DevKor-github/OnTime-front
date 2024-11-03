import '/core/database/database.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';

class PreparationUserEntity {
  final int id;
  final UserEntity user;
  final String preparationName;
  final int preparationTime;
  final int order;

  PreparationUserEntity({
    required this.id,
    required this.user,
    required this.preparationName,
    required this.preparationTime,
    required this.order,
  });

  static PreparationUserEntity fromModel(
      PreparationSchedule preparationSchedule, User user) {
    return PreparationUserEntity(
      id: preparationSchedule.id,
      user: UserEntity.fromModel(user),
      preparationName: preparationSchedule.preparationName,
      preparationTime: preparationSchedule.preparationTime,
      order: preparationSchedule.order,
    );
  }

  PreparationUser toModel() {
    return PreparationUser(
      id: id,
      userId: user.id,
      preparationName: preparationName,
      preparationTime: preparationTime,
      order: order,
    );
  }

  @override
  String toString() {
    return 'PreparationUserEntity(id: $id, user: $user, preparationName: $preparationName, preparationTime: $preparationTime, order: $order)';
  }
}
