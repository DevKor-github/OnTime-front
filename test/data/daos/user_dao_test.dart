import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/data/daos/user_dao.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';

void main() {
  late AppDatabase database;
  late UserDao dao;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    dao = UserDao(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('createUser persists the user profile fields', () async {
    await dao.createUser(_user);

    final saved = await dao.getUserById('user-1');

    expect(saved, _user);
  });

  test('getUserById returns null for an unknown user', () async {
    expect(await dao.getUserById('missing-user'), isNull);
  });

  test('getAllUsers returns all persisted users as domain entities', () async {
    const secondUser = UserEntity(
      id: 'user-2',
      email: 'second@example.com',
      name: 'Second User',
      spareTime: Duration(minutes: 20),
      note: 'second note',
      score: 3.5,
    );

    await dao.createUser(_user);
    await dao.createUser(secondUser);

    final users = await dao.getAllUsers();

    expect(users, containsAll([_user, secondUser]));
    expect(users, hasLength(2));
  });
}

const _user = UserEntity(
  id: 'user-1',
  email: 'user@example.com',
  name: 'Test User',
  spareTime: Duration(minutes: 15),
  note: 'note',
  score: 4.5,
);
