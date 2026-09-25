import 'package:on_time_front/core/time/schedule_time_resolution.dart';
import 'package:on_time_front/data/repositories/schedule_aggregate_repository_impl.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/data/mappers/domain_persistence_mappers.dart';
import 'package:on_time_front/domain/repositories/recurring_schedule_repository.dart';
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
    RecurringScheduleRepository? recurringScheduleRepository,
  }) : _database = database,
       _recurring = recurringScheduleRepository,
       _userDao = database.userDao;

  final AppDatabase _database;
  final RecurringScheduleRepository? _recurring;
  final UserDao _userDao;

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
    await _database.writeTransaction(
      () => _userDao.updateAlarmSettings(
        userId: localProfileId,
        enabled: alarmsEnabled,
      ),
    );
    return getAlarmSettings();
  }

  @override
  Future<List<ScheduleWithPreparationEntity>> getAlarmWindow(
    DateTime startDate,
    DateTime endDate,
  ) async {
    // Reconciliation has a long search horizon but the platform can only hold
    // a bounded pending set. Supply the nearest candidates from each series.
    final evaluationNow = DateTime.now().toUtc();
    final civilStart = startDate.subtract(const Duration(days: 2));
    await _recurring?.materialize(civilStart, endDate, perSeriesLimit: 64);
    return _database.transaction(() async {
      final schedules = (await _database.scheduleDao.getSchedulesByDate(
        _recurring == null ? startDate : civilStart,
        _recurring == null ? endDate : endDate.add(const Duration(days: 2)),
      )).map((r) => r.toScheduleEntity());
      final result = <ScheduleWithPreparationEntity>[];
      for (final schedule in schedules) {
        if (schedule.retainedRecurringReference) continue;
        final preparation = await readSchedulePreparation(_database, schedule);
        result.add(
          ScheduleWithPreparationEntity.fromScheduleAndPreparationEntity(
            schedule,
            PreparationWithTimeEntity.fromPreparation(preparation),
            timeResolution: ScheduleTimeResolver.resolve(
              schedule,
              nowUtc: evaluationNow,
            ),
          ),
        );
      }
      return List.unmodifiable(result);
    });
  }
}
