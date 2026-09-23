import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/constants/local_profile.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/data/daos/user_dao.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/repositories/user_repository.dart';
import 'package:rxdart/subjects.dart';

@Singleton(as: UserRepository)
class UserRepositoryImpl implements UserRepository {
  UserRepositoryImpl(this._database) : _userDao = _database.userDao {
    _subscription = _userDao.watchUserById(localProfileId).listen((user) {
      if (user != null) _userStreamController.add(user);
    });
  }

  final AppDatabase _database;
  final UserDao _userDao;
  final _userStreamController = BehaviorSubject<UserEntity>.seeded(
    const UserEntity.empty(),
  );
  late final StreamSubscription<UserEntity?> _subscription;

  @override
  Stream<UserEntity> get userStream => _userStreamController.stream;

  @override
  Future<UserEntity> getUser() async {
    final existing = await _userDao.getUserById(localProfileId);
    if (existing != null) {
      _userStreamController.add(existing);
      return existing;
    }

    const profile = UserEntity(
      id: localProfileId,
      spareTime: Duration.zero,
      note: '',
    );
    await _userDao.putUser(profile);
    final stored = (await _userDao.getUserById(localProfileId))!;
    _userStreamController.add(stored);
    return stored;
  }

  @override
  Future<void> updateSpareTime(Duration spareTime) async {
    await _userDao.updateSpareTime(localProfileId, spareTime);
  }

  @override
  Future<void> resetLocalData() async {
    await _database.deleteAllDurableData();
    _userStreamController.add(const UserEntity.empty());
    await getUser();
  }

  Future<void> dispose() async {
    await _subscription.cancel();
    await _userStreamController.close();
  }
}
