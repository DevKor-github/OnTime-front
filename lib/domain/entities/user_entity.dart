import '/core/database/database.dart';

class UserEntity {
  final String id;
  final String email;
  final String name;
  final int spareTime;
  final String note;
  final double score;
  final bool isOnboardingCompleted;

  UserEntity(
      {required this.id,
      required this.email,
      required this.name,
      required this.spareTime,
      required this.note,
      required this.score,
      this.isOnboardingCompleted = false});

  static UserEntity fromModel(User user) {
    return UserEntity(
      id: user.id,
      email: user.email,
      name: user.name,
      spareTime: user.spareTime,
      note: user.note,
      score: user.score,
    );
  }

  User toModel() {
    return User(
      id: id,
      email: email,
      name: name,
      spareTime: spareTime,
      note: note,
      score: score,
    );
  }

  @override
  String toString() {
    return 'UserEntity(id: $id, email: $email, name: $name, spareTime: $spareTime, note: $note, score: $score)';
  }
}
