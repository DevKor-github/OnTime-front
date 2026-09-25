import 'package:on_time_front/core/startup/startup_dependency_scope.dart';
import 'package:on_time_front/core/startup/subscription_cleanup.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/constants/local_profile.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/data/daos/user_dao.dart';
import 'package:on_time_front/data/data_sources/preparation_local_data_source.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/repositories/preparation_repository.dart';
import 'package:on_time_front/domain/repositories/user_repository.dart';
import 'package:rxdart/subjects.dart';

Future<void> disposePreparationRepository(PreparationRepository resource) =>
    StartupDependencyScope.release(
      resource,
      (resource as PreparationRepositoryImpl).dispose,
    );

@Singleton(as: PreparationRepository, dispose: disposePreparationRepository)
class PreparationRepositoryImpl implements PreparationRepository {
  PreparationRepositoryImpl({
    required PreparationLocalDataSource preparationLocalDataSource,
    required UserRepository userRepository,
    required AppDatabase database,
  }) : _localDataSource = preparationLocalDataSource,
       _userRepository = userRepository,
       _userDao = database.userDao,
       _database = database {
    StartupDependencyScope.own(this, dispose);
    LocalDataOperationGate.shared.addListener(_observeCurrentGeneration);
    _observeCurrentGeneration();
  }

  StreamSubscription<Map<String, PreparationEntity>>? _subscription;
  int _watchGeneration = -1;
  Object? _subscriptionOwner;

  bool _isCurrentWatch(Object owner, int generation) {
    final gate = LocalDataOperationGate.shared;
    return identical(owner, _subscriptionOwner) &&
        generation == gate.generation &&
        !gate.isReplacingData &&
        !gate.isRecoveryPending &&
        !gate.isInvalidated;
  }

  final _retiredWatches = SubscriptionCleanup();
  bool _disposed = false;
  Future<void>? _subjectClose;
  Future<void>? _disposeFlight;
  void _observeCurrentGeneration() {
    if (_disposed) return;
    final gate = LocalDataOperationGate.shared;
    if (_watchGeneration != gate.generation ||
        gate.isReplacingData ||
        gate.isRecoveryPending ||
        gate.isInvalidated) {
      // Retire the token before cancellation finishes: old reads and errors
      // cannot publish into the replacement installation.
      _subscriptionOwner = null;
      _retiredWatches.retire(_subscription);
      _subscription = null;
      _preparationStreamController.add(const {});
    }
    if (_subscription != null ||
        gate.isReplacingData ||
        gate.isRecoveryPending ||
        gate.isInvalidated) {
      return;
    }
    final generation = gate.generation;
    final owner = Object();
    _watchGeneration = generation;
    _subscriptionOwner = owner;
    _subscription = _database
        .customSelect(
          'SELECT count(*) AS n FROM schedules',
          readsFrom: {
            _database.schedules,
            _database.preparationSchedules,
            _database.preparationDefinitions,
            _database.preparationDefinitionSteps,
            _database.preparationUsers,
            _database.preparationTemplates,
            _database.preparationTemplateSteps,
          },
        )
        .watch()
        .asyncMap(
          (_) => _database.transaction(() async {
            final schedules = await _database.select(_database.schedules).get();
            return {
              for (final schedule in schedules)
                schedule.id: await _localDataSource.getPreparationByScheduleId(
                  schedule.id,
                ),
            };
          }),
        )
        .listen(
          (value) {
            if (_isCurrentWatch(owner, generation)) {
              _preparationStreamController.add(value);
            }
          },
          onError: (Object error, StackTrace stack) {
            if (_isCurrentWatch(owner, generation)) {
              _preparationStreamController.addError(error, stack);
            }
          },
        );
  }

  final PreparationLocalDataSource _localDataSource;
  final UserRepository _userRepository;
  final UserDao _userDao;
  final AppDatabase _database;
  final _preparationStreamController =
      BehaviorSubject<Map<String, PreparationEntity>>.seeded(const {});

  @override
  Stream<Map<String, PreparationEntity>> get preparationStream =>
      _preparationStreamController.stream;

  @override
  Future<void> createDefaultPreparation({
    required PreparationEntity preparationEntity,
    required Duration spareTime,
    required String note,
  }) async {
    await _database.writeTransaction(() async {
      await _userRepository.getUser();
      final existing = await _localDataSource.getDefaultPreparation(
        localProfileId,
      );
      final changed = !_samePreparation(existing, preparationEntity);
      if (changed) {
        await _localDataSource.createDefaultPreparation(
          preparationEntity.ordered,
          userId: localProfileId,
        );
      }
      await _userDao.completeOnboarding(
        userId: localProfileId,
        spareTime: spareTime,
        note: note,
        preparationChanged: changed,
      );
    });
  }

  @override
  Future<void> createCustomPreparation(
    PreparationEntity preparationEntity,
    String scheduleId,
  ) async {
    final generation = LocalDataOperationGate.shared.generation;
    await _database.writeTransaction(() async {
      await _localDataSource.createCustomPreparation(
        preparationEntity,
        scheduleId,
      );
      await _userDao.markDurableDataChanged(localProfileId);
    });
    if (generation == LocalDataOperationGate.shared.generation) {
      _emitSchedulePreparation(scheduleId, preparationEntity);
    }
  }

  @override
  Future<void> getPreparationByScheduleId(String scheduleId) async {
    final generation = LocalDataOperationGate.shared.generation;
    final preparation = await _localDataSource.getPreparationByScheduleId(
      scheduleId,
    );
    if (generation == LocalDataOperationGate.shared.generation) {
      _emitSchedulePreparation(scheduleId, preparation);
    }
  }

  @override
  Future<PreparationEntity> getDefualtPreparation() {
    return _localDataSource.getDefaultPreparation(localProfileId);
  }

  @override
  Future<void> updateDefaultPreparation(
    PreparationEntity preparationEntity,
  ) async {
    await _database.writeTransaction(() async {
      await _localDataSource.replaceDefaultPreparation(
        preparationEntity,
        userId: localProfileId,
      );
      await _userDao.markDurableDataChanged(localProfileId);
    });
  }

  @override
  Future<void> updatePreparationByScheduleId(
    PreparationEntity preparationEntity,
    String scheduleId,
  ) async {
    final generation = LocalDataOperationGate.shared.generation;
    await _database.writeTransaction(() async {
      await _localDataSource.replaceSchedulePreparation(
        preparationEntity,
        scheduleId: scheduleId,
      );
      await _userDao.markDurableDataChanged(localProfileId);
    });
    if (generation == LocalDataOperationGate.shared.generation) {
      _emitSchedulePreparation(scheduleId, preparationEntity);
    }
  }

  @override
  Future<void> updateSpareTime(Duration newSpareTime) =>
      _userRepository.updateSpareTime(newSpareTime);

  bool _samePreparation(PreparationEntity left, PreparationEntity right) {
    final a = left.ordered.preparationStepList;
    final b = right.ordered.preparationStepList;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      // Links are reconstructed by storage from this order; callers may omit them.
      if (a[i].id != b[i].id ||
          a[i].preparationName != b[i].preparationName ||
          a[i].preparationTime.inMinutes != b[i].preparationTime.inMinutes) {
        return false;
      }
    }
    return true;
  }

  void _emitSchedulePreparation(
    String scheduleId,
    PreparationEntity preparation,
  ) {
    if (_disposed) return;
    _preparationStreamController.add({
      ..._preparationStreamController.value,
      scheduleId: preparation,
    });
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
      _subjectClose ??= _preparationStreamController.close(),
    ]);
  }
}
