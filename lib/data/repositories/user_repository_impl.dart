import 'package:on_time_front/core/startup/startup_dependency_scope.dart';
import 'package:on_time_front/core/startup/subscription_cleanup.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/database/restore_runtime_identity.dart';
import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/constants/local_profile.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/data/daos/user_dao.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/repositories/user_repository.dart';
import 'package:rxdart/subjects.dart';

Future<void> disposeUserRepository(UserRepository resource) =>
    StartupDependencyScope.release(
      resource,
      (resource as UserRepositoryImpl).dispose,
    );

@Singleton(as: UserRepository, dispose: disposeUserRepository)
class UserRepositoryImpl implements UserRepository {
  UserRepositoryImpl(this._database) : _userDao = _database.userDao {
    StartupDependencyScope.own(this, dispose);
    LocalDataOperationGate.shared.addListener(_observeCurrentGeneration);
    _observeCurrentGeneration();
  }

  final AppDatabase _database;
  final UserDao _userDao;
  final _userStreamController = BehaviorSubject<UserEntity>.seeded(
    const UserEntity.empty(),
  );
  StreamSubscription<UserEntity?>? _subscription;
  int _watchGeneration = -1;
  Object? _subscriptionOwner;
  Object _publicationOwner = Object();

  void _publish(UserEntity user) {
    _publicationOwner = Object();
    if (!_userStreamController.isClosed) _userStreamController.add(user);
  }

  void _publishRead(UserEntity user, Object owner) {
    // A newer watch/read publication wins over a delayed one-shot reload.
    if (identical(owner, _publicationOwner)) _publish(user);
  }

  final _retiredWatches = SubscriptionCleanup();
  bool _disposed = false;
  Future<void>? _subjectClose;
  Future<void>? _disposeFlight;
  void _observeCurrentGeneration() {
    if (_disposed) return;
    final gate = LocalDataOperationGate.shared;
    if (_watchGeneration != gate.generation ||
        gate.isRecoveryPending ||
        gate.isInvalidated) {
      _subscriptionOwner = null;
      _retiredWatches.retire(_subscription);
      _subscription = null;
      _publish(const UserEntity.empty());
    }
    if (_subscription != null ||
        gate.isReplacingData ||
        gate.isRecoveryPending ||
        gate.isInvalidated) {
      return;
    }
    final generation = gate.generation;
    _watchGeneration = generation;
    final owner = Object();
    _subscriptionOwner = owner;
    _subscription = _userDao.watchUserById(localProfileId).listen((user) {
      if (identical(owner, _subscriptionOwner) &&
          generation == gate.generation &&
          !gate.isReplacingData &&
          !gate.isRecoveryPending &&
          !gate.isInvalidated &&
          user != null) {
        _publish(user);
      }
    });
  }

  @override
  Stream<UserEntity> get userStream => _userStreamController.stream;

  @override
  Future<UserEntity> getUser() async {
    final gate = LocalDataOperationGate.shared;
    final generation = gate.captureWrite();
    final publication = _publicationOwner;
    final existing = await _userDao.getUserById(localProfileId);
    gate.checkWrite(generation);
    if (existing != null) {
      await RestoreRuntimeIdentity.shared.load(_database);
      gate.checkWrite(generation);
      _publishRead(existing, publication);
      return existing;
    }

    const profile = UserEntity(
      id: localProfileId,
      spareTime: Duration.zero,
      note: '',
    );
    gate.checkWrite(generation);
    await _database.writeTransaction(() async {
      gate.checkWrite(generation);
      await _userDao.putUser(profile);
    });
    await RestoreRuntimeIdentity.shared.load(_database);
    final stored = (await _userDao.getUserById(localProfileId))!;
    gate.checkWrite(generation);
    _publishRead(stored, publication);
    return stored;
  }

  @override
  Future<void> updateSpareTime(Duration spareTime) async {
    await _database.writeTransaction(
      () => _userDao.updateSpareTime(localProfileId, spareTime),
    );
  }

  @override
  Future<void> resetLocalData() async {
    await _database.deleteAllDurableData();
    _publish(const UserEntity.empty());
    await getUser();
  }

  Future<void> dispose() =>
      _disposeFlight ??= _dispose().whenComplete(() => _disposeFlight = null);
  Future<void> _dispose() async {
    _disposed = true;
    LocalDataOperationGate.shared.removeListener(_observeCurrentGeneration);
    _subscriptionOwner = null;
    _retiredWatches.retire(_subscription);
    _subscription = null;
    await Future.wait([
      _retiredWatches.close(),
      _subjectClose ??= _userStreamController.close(),
    ]);
  }
}
