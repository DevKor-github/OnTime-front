import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/data/daos/preparation_user_dao.dart';
import 'package:uuid/uuid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PreparationUserDao preparationUserDao;
  late AppDatabase appDatabase;

  final uuid = Uuid();

  final userId = uuid.v7();

  final tPreparationUsers = [
    PreparationUser(
      id: uuid.v7(),
      userId: userId,
      preparationName: 'Test Preparation',
      preparationTime: 10,
      order: 1,
    ),
    PreparationUser(
      id: uuid.v7(),
      userId: userId,
      preparationName: 'Test Preparation 2',
      preparationTime: 10,
      order: 2,
    ),
  ];

  setUp(() {
    appDatabase = AppDatabase.forTesting(NativeDatabase.memory());
    preparationUserDao = PreparationUserDao(appDatabase);
  });

  group('createPreparationUsers', () {
    test('should insert a preparation users into the database', () async {
      // Act
      final result = await preparationUserDao.createPreparationUsers(
        tPreparationUsers,
      );

      // Assert
      expect(result, equals(tPreparationUsers));
    });
  });

  group('getPreparationUsersByUserId', () {
    test('should return a list of preparation users by userId', () async {
      // Arrange
      for (var step in tPreparationUsers) {
        await appDatabase.into(appDatabase.preparationUsers).insertReturning(
              step.toCompanion(false),
            );
      }

      // Act
      final result =
          await preparationUserDao.getPreparationUsersByUserId(userId);

      // Assert
      expect(result, equals(tPreparationUsers));
    });
  });

  group('deletePreparationUsersByUserId', () {
    test('should delete a list of preparation users by userId', () async {
      // Arrange
      for (var step in tPreparationUsers) {
        await appDatabase.into(appDatabase.preparationUsers).insertReturning(
              step.toCompanion(false),
            );
      }

      // Act
      await preparationUserDao.deletePreparationUsersByUserId(userId);

      // Assert
      final result = await (appDatabase.select(appDatabase.preparationUsers)
            ..where((tbl) => tbl.userId.equals(userId)))
          .get();
      expect(result, equals([]));
    });
  });
}
