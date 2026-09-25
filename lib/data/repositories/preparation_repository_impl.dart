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

@Singleton(as: PreparationRepository)
class PreparationRepositoryImpl implements PreparationRepository {
  PreparationRepositoryImpl({
    required PreparationLocalDataSource preparationLocalDataSource,
    required UserRepository userRepository,
    required AppDatabase database,
  }) : _localDataSource = preparationLocalDataSource,
       _userRepository = userRepository,
       _userDao = database.userDao,
       _database = database {
    _subscription = database
        .customSelect(
          'SELECT count(*) AS n FROM schedules',
          readsFrom: {
            database.schedules,
            database.preparationSchedules,
            database.preparationDefinitions,
            database.preparationDefinitionSteps,
            database.preparationUsers,
            database.preparationTemplates,
            database.preparationTemplateSteps,
          },
        )
        .watch()
        .asyncMap(
          (_) => database.transaction(() async {
            final schedules = await database.select(database.schedules).get();
            return {
              for (final schedule in schedules)
                schedule.id: await _localDataSource.getPreparationByScheduleId(
                  schedule.id,
                ),
            };
          }),
        )
        .listen(
          _preparationStreamController.add,
          onError: _preparationStreamController.addError,
        );
  }

  late final StreamSubscription<Map<String, PreparationEntity>> _subscription;
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
    await _userRepository.getUser();
    await _database.transaction(() async {
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
    await _database.transaction(() async {
      await _localDataSource.createCustomPreparation(
        preparationEntity,
        scheduleId,
      );
      await _userDao.markDurableDataChanged(localProfileId);
    });
    _emitSchedulePreparation(scheduleId, preparationEntity);
  }

  @override
  Future<void> getPreparationByScheduleId(String scheduleId) async {
    final preparation = await _localDataSource.getPreparationByScheduleId(
      scheduleId,
    );
    _emitSchedulePreparation(scheduleId, preparation);
  }

  @override
  Future<PreparationEntity> getDefualtPreparation() {
    return _localDataSource.getDefaultPreparation(localProfileId);
  }

  @override
  Future<void> updateDefaultPreparation(
    PreparationEntity preparationEntity,
  ) async {
    await _localDataSource.replaceDefaultPreparation(
      preparationEntity,
      userId: localProfileId,
    );
    await _userDao.markDurableDataChanged(localProfileId);
  }

  @override
  Future<void> updatePreparationByScheduleId(
    PreparationEntity preparationEntity,
    String scheduleId,
  ) async {
    await _database.transaction(() async {
      await _localDataSource.replaceSchedulePreparation(
        preparationEntity,
        scheduleId: scheduleId,
      );
      await _userDao.markDurableDataChanged(localProfileId);
    });
    _emitSchedulePreparation(scheduleId, preparationEntity);
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
    _preparationStreamController.add({
      ..._preparationStreamController.value,
      scheduleId: preparation,
    });
  }

  Future<void> dispose() async {
    await _subscription.cancel();
    await _preparationStreamController.close();
  }
}
