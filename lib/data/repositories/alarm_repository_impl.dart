import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/constants/local_profile.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/data/daos/user_dao.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/repositories/alarm_repository.dart';
import 'package:on_time_front/domain/repositories/preparation_repository.dart';
import 'package:on_time_front/domain/repositories/schedule_repository.dart';

@Singleton(as: AlarmRepository)
class AlarmRepositoryImpl implements AlarmRepository {
  AlarmRepositoryImpl({
    required AppDatabase database,
    required ScheduleRepository scheduleRepository,
    required PreparationRepository preparationRepository,
  }) : _userDao = database.userDao,
       _scheduleRepository = scheduleRepository,
       _preparationRepository = preparationRepository;

  final UserDao _userDao;
  final ScheduleRepository _scheduleRepository;
  final PreparationRepository _preparationRepository;

  @override
  Future<AlarmSettings> getAlarmSettings() async {
    final settings = await _userDao.getAlarmSettings(localProfileId);
    return AlarmSettings(
      alarmsEnabled: settings.enabled,
      defaultAlarmOffsetMinutes: settings.offsetMinutes,
      detailedNotificationContent: settings.detailedNotificationContent,
    );
  }

  @override
  Future<AlarmSettings> updateAlarmSettings({
    required bool alarmsEnabled,
  }) async {
    await _userDao.updateAlarmSettings(
      userId: localProfileId,
      enabled: alarmsEnabled,
    );
    return AlarmSettings(
      alarmsEnabled: alarmsEnabled,
      defaultAlarmOffsetMinutes: 0,
      updatedAt: DateTime.now(),
      detailedNotificationContent: (await _userDao.getAlarmSettings(
        localProfileId,
      )).detailedNotificationContent,
    );
  }

  @override
  Future<List<ScheduleWithPreparationEntity>> getAlarmWindow(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final schedules = await _scheduleRepository.getSchedulesByDate(
      startDate,
      endDate,
    );
    final defaultPreparation = await _preparationRepository
        .getDefualtPreparation();
    final result = <ScheduleWithPreparationEntity>[];
    for (final schedule in schedules) {
      await _preparationRepository.getPreparationByScheduleId(schedule.id);
      final custom = await _preparationRepository.preparationStream.first.then(
        (preparations) => preparations[schedule.id],
      );
      result.add(
        ScheduleWithPreparationEntity.fromScheduleAndPreparationEntity(
          schedule,
          PreparationWithTimeEntity.fromPreparation(
            custom == null || custom.preparationStepList.isEmpty
                ? defaultPreparation
                : custom,
          ),
        ),
      );
    }
    return result;
  }
}
