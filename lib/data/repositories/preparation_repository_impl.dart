import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/constants/local_profile.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/data/daos/user_dao.dart';
import 'package:on_time_front/data/data_sources/preparation_local_data_source.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
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
       _userDao = database.userDao;

  final PreparationLocalDataSource _localDataSource;
  final UserRepository _userRepository;
  final UserDao _userDao;
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
    await _localDataSource.createDefaultPreparation(
      preparationEntity,
      userId: localProfileId,
    );
    final profile = (await _userRepository.getUser()).valueOrNull!;
    await _userRepository.saveUser(
      UserEntity(
        id: profile.id,
        spareTime: spareTime,
        note: note,
        isOnboardingCompleted: true,
        eligibleOutcomeCount: profile.eligibleOutcomeCount,
        onTimeOutcomeCount: profile.onTimeOutcomeCount,
      ),
    );
  }

  @override
  Future<void> createCustomPreparation(
    PreparationEntity preparationEntity,
    String scheduleId,
  ) async {
    await _localDataSource.createCustomPreparation(
      preparationEntity,
      scheduleId,
    );
    _emitSchedulePreparation(scheduleId, preparationEntity);
    await _userDao.markDurableDataChanged(localProfileId);
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
    await _localDataSource.replaceSchedulePreparation(
      preparationEntity,
      scheduleId: scheduleId,
    );
    _emitSchedulePreparation(scheduleId, preparationEntity);
    await _userDao.markDurableDataChanged(localProfileId);
  }

  @override
  Future<void> updateSpareTime(Duration newSpareTime) async {
    final profile = (await _userRepository.getUser()).valueOrNull!;
    await _userRepository.saveUser(
      UserEntity(
        id: profile.id,
        spareTime: newSpareTime,
        note: profile.note,
        isOnboardingCompleted: profile.isOnboardingCompleted,
        eligibleOutcomeCount: profile.eligibleOutcomeCount,
        onTimeOutcomeCount: profile.onTimeOutcomeCount,
      ),
    );
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

  Future<void> dispose() => _preparationStreamController.close();
}
