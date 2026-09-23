import 'dart:async';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/constants/local_profile.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/data/daos/schedule_dao.dart';
import 'package:on_time_front/data/daos/user_dao.dart';
import 'package:on_time_front/data/mappers/domain_persistence_mappers.dart';
import 'package:on_time_front/data/tables/schedule_with_place_model.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/repositories/schedule_repository.dart';
import 'package:on_time_front/domain/repositories/timed_preparation_repository.dart';
import 'package:rxdart/subjects.dart';

@Singleton(as: ScheduleRepository)
class ScheduleRepositoryImpl implements ScheduleRepository {
  ScheduleRepositoryImpl({
    required AppDatabase database,
    required TimedPreparationRepository timedPreparationRepository,
  }) : _database = database,
       _scheduleDao = database.scheduleDao,
       _userDao = database.userDao,
       _timedPreparationRepository = timedPreparationRepository {
    _subscription = _scheduleDao.watchScheduleList().listen(
      (rows) => _scheduleStreamController.add(
        rows.map((row) => row.toScheduleEntity()).toSet(),
      ),
    );
  }

  final AppDatabase _database;
  final ScheduleDao _scheduleDao;
  final UserDao _userDao;
  final TimedPreparationRepository _timedPreparationRepository;
  final _scheduleStreamController = BehaviorSubject<Set<ScheduleEntity>>.seeded(
    const {},
  );
  late final StreamSubscription<List<ScheduleWithPlace>> _subscription;

  @override
  Stream<Set<ScheduleEntity>> get scheduleStream =>
      _scheduleStreamController.stream;

  @override
  Stream<List<ScheduleEntity>> watchSchedulesByDate(
    DateTime startDate,
    DateTime endDate,
  ) {
    return scheduleStream
        .map((schedules) {
          final result = schedules
              .where(
                (schedule) =>
                    !schedule.scheduleTime.isBefore(startDate) &&
                    schedule.scheduleTime.isBefore(endDate),
              )
              .toList();
          result.sort((a, b) => a.scheduleTime.compareTo(b.scheduleTime));
          return result;
        })
        .distinct(const DeepCollectionEquality().equals);
  }

  @override
  Future<void> createSchedule(ScheduleEntity schedule) async {
    await _scheduleDao.createSchedule(schedule.toScheduleWithPlaceRow());
    await _userDao.markDurableDataChanged(localProfileId);
  }

  @override
  Future<void> deleteSchedule(ScheduleEntity schedule) async {
    await _scheduleDao.deleteSchedule(schedule.toScheduleRow());
    await _clearTimedPreparation(schedule.id);
    await _userDao.markDurableDataChanged(localProfileId);
  }

  @override
  Future<void> startSchedule(String scheduleId) async {
    final existing = await _scheduleDao.getScheduleById(scheduleId);
    await _scheduleDao.updateSchedule(
      existing.schedule.copyWith(
        isStarted: true,
        startedAt: Value(DateTime.now()),
        preparationFrozen: true,
      ),
    );
    await _userDao.markDurableDataChanged(localProfileId);
  }

  @override
  Future<ScheduleEntity> getScheduleById(String id) async {
    return (await _scheduleDao.getScheduleById(id)).toScheduleEntity();
  }

  @override
  Future<List<ScheduleEntity>> getSchedulesByDate(
    DateTime startDate,
    DateTime? endDate,
  ) async {
    final rows = await _scheduleDao.getSchedulesByDate(startDate, endDate);
    return rows.map((row) => row.toScheduleEntity()).toList();
  }

  @override
  Future<void> updateSchedule(
    ScheduleEntity schedule, {
    bool includePreparationSource = false,
  }) async {
    await _scheduleDao.updateScheduleWithPlace(
      schedule.toScheduleWithPlaceRow(),
    );
    // Retain the old content-free identity until the session validator sees
    // this edit. Deleting it would make an invalid run look like a fresh one
    // and allow automatic catch-up. Unchanged timing/shape stays resumable.
    await _userDao.markDurableDataChanged(localProfileId);
  }

  @override
  Future<void> finishSchedule(String scheduleId, int latenessTime) async {
    await _database.transaction(() async {
      final existing = await _scheduleDao.getScheduleById(scheduleId);
      if (existing.schedule.doneStatus != ScheduleDoneStatus.notEnded.name) {
        return;
      }

      final doneStatus = latenessTime > 0
          ? ScheduleDoneStatus.lateEnd
          : ScheduleDoneStatus.normalEnd;
      await _scheduleDao.updateSchedule(
        existing.schedule.copyWith(
          isStarted: false,
          latenessTime: latenessTime,
          doneStatus: doneStatus.name,
          finishedAt: Value(DateTime.now()),
          scoreContributionRecorded: true,
        ),
      );

      if (!existing.schedule.scoreContributionRecorded) {
        await _userDao.incrementScore(
          localProfileId,
          onTime: latenessTime <= 0,
        );
      }
      await _userDao.markDurableDataChanged(localProfileId);
    });
    await _clearTimedPreparation(scheduleId);
  }

  Future<void> _clearTimedPreparation(String scheduleId) async {
    try {
      await _timedPreparationRepository.clearTimedPreparation(scheduleId);
    } catch (_) {
      // Active timer state is reconstructible and must not fail durable writes.
    }
  }

  Future<void> dispose() async {
    await _subscription.cancel();
    await _scheduleStreamController.close();
  }
}
