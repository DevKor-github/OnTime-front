import 'package:on_time_front/domain/entities/schedule_deletion.dart';
import 'package:on_time_front/data/repositories/schedule_aggregate_repository_impl.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/core/time/schedule_time_resolution.dart';
import 'package:on_time_front/domain/entities/civil_date_time.dart';
import 'package:on_time_front/core/startup/startup_dependency_scope.dart';
import 'package:on_time_front/core/startup/subscription_cleanup.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/domain/entities/schedule_start_rejected.dart';
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
import 'package:on_time_front/domain/repositories/recurring_schedule_repository.dart';
import 'package:on_time_front/domain/recurrence/recurring_schedule.dart';

Future<void> disposeScheduleRepository(ScheduleRepository resource) =>
    StartupDependencyScope.release(
      resource,
      (resource as ScheduleRepositoryImpl).dispose,
    );

@Singleton(as: ScheduleRepository, dispose: disposeScheduleRepository)
class ScheduleRepositoryImpl implements ScheduleRepository {
  ScheduleRepositoryImpl({
    required AppDatabase database,
    required TimedPreparationRepository timedPreparationRepository,
    RecurringScheduleRepository? recurringScheduleRepository,
    @ignoreParam DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       _recurring = recurringScheduleRepository,
       _database = database,
       _scheduleDao = database.scheduleDao,
       _userDao = database.userDao,
       _timedPreparationRepository = timedPreparationRepository {
    StartupDependencyScope.own(this, dispose);
    LocalDataOperationGate.shared.addListener(_observeCurrentGeneration);
    _observeCurrentGeneration();
  }

  final DateTime Function() _now;
  final RecurringScheduleRepository? _recurring;
  final AppDatabase _database;
  final ScheduleDao _scheduleDao;
  final UserDao _userDao;
  final TimedPreparationRepository _timedPreparationRepository;
  final _scheduleStreamController = BehaviorSubject<Set<ScheduleEntity>>.seeded(
    const {},
  );
  StreamSubscription<List<ScheduleWithPlace>>? _subscription;
  int _watchGeneration = -1;
  Object? _subscriptionOwner;
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
      _scheduleStreamController.add(const {});
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
    _subscription = _scheduleDao.watchScheduleList().listen(
      (rows) {
        if (identical(owner, _subscriptionOwner) &&
            generation == gate.generation &&
            !gate.isReplacingData &&
            !gate.isRecoveryPending &&
            !gate.isInvalidated) {
          _scheduleStreamController.add(
            rows.map((row) => row.toScheduleEntity()).toSet(),
          );
        }
      },
      onError: (Object error, StackTrace stack) {
        if (identical(owner, _subscriptionOwner) &&
            generation == gate.generation &&
            !gate.isInvalidated &&
            !gate.isReplacingData) {
          _scheduleStreamController.addError(error, stack);
        }
      },
    );
  }

  @override
  Stream<Set<ScheduleEntity>> get scheduleStream =>
      _scheduleStreamController.stream;

  @override
  Stream<List<ScheduleEntity>> watchSchedulesByDate(
    DateTime startDate,
    DateTime endDate,
  ) async* {
    await _recurring?.materialize(startDate, endDate);
    yield* scheduleStream
        .map((schedules) {
          final result = schedules
              .where(
                (schedule) =>
                    !CivilDateTime.fromFields(
                      schedule.scheduleTime,
                    ).toUtcCarrier().isBefore(
                      CivilDateTime.fromFields(startDate).toUtcCarrier(),
                    ) &&
                    CivilDateTime.fromFields(
                      schedule.scheduleTime,
                    ).toUtcCarrier().isBefore(
                      CivilDateTime.fromFields(endDate).toUtcCarrier(),
                    ),
              )
              .toList();
          result.sort((a, b) => a.scheduleTime.compareTo(b.scheduleTime));
          return result;
        })
        .distinct(const DeepCollectionEquality().equals);
  }

  @override
  Future<void> createSchedule(ScheduleEntity schedule) async {
    await _database.writeTransaction(() async {
      await _scheduleDao.createSchedule(schedule.toScheduleWithPlaceRow());
      await _userDao.markDurableDataChanged(localProfileId);
    });
  }

  @override
  Future<void> deleteSchedule(ScheduleEntity schedule) async {
    final generation = LocalDataOperationGate.shared.captureWrite();
    await _database.writeTransaction(() async {
      final current = await (_database.select(
        _database.schedules,
      )..where((row) => row.id.equals(schedule.id))).getSingleOrNull();
      if (current == null) return;
      if (current.isStarted) {
        throw const ScheduleDeletionRejected(ScheduleDeletionFailure.protected);
      }
      if (current.recurringSegmentId != null && _recurring != null) {
        final latest = (await _scheduleDao.getScheduleById(
          schedule.id,
        )).toScheduleEntity();
        await _recurring.delete(latest, RecurringEditScope.occurrence);
      } else {
        await _scheduleDao.deleteSchedule(current);
        await _userDao.markDurableDataChanged(localProfileId);
      }
    });
    if (generation == LocalDataOperationGate.shared.generation) {
      await _clearTimedPreparation(schedule.id);
    }
  }

  @override
  Future<DateTime> startSchedule(
    String scheduleId, {
    DateTime? startedAt,
    bool Function()? isCurrent,
    String? expectedFingerprint,
  }) => _database.writeTransaction(() async {
    void checkIntent() {
      if (!(isCurrent?.call() ?? true)) throw ScheduleStartRejected(scheduleId);
    }

    checkIntent();
    final joined = await _scheduleDao.getScheduleById(scheduleId);
    checkIntent();
    final existing = joined.schedule;
    if (expectedFingerprint != null) {
      final actual = joined.toScheduleEntity();
      if (actual.preparationDefinitionId != null) {
        final definition =
            await (_database.select(_database.preparationDefinitions)..where(
                  (row) => row.id.equals(actual.preparationDefinitionId!),
                ))
                .getSingleOrNull();
        checkIntent();
        if (definition == null) throw ScheduleStartRejected(scheduleId);
      }
      final preparation = await readSchedulePreparation(_database, actual);
      checkIntent();
      final resolution = ScheduleTimeResolver.resolve(
        actual,
        nowUtc: _now().toUtc(),
      );
      if (resolution.instantUtc == null) {
        throw ScheduleStartRejected(scheduleId);
      }
      final interpreted =
          ScheduleWithPreparationEntity.fromScheduleAndPreparationEntity(
            actual,
            PreparationWithTimeEntity.fromPreparation(preparation),
            timeResolution: resolution,
          );
      if (interpreted.cacheFingerprint != expectedFingerprint) {
        throw ScheduleStartRejected(scheduleId);
      }
    }
    if (joined.retainedRecurringReference && !existing.isStarted) {
      throw ScheduleStartRejected(scheduleId);
    }
    if (existing.doneStatus != ScheduleDoneStatus.notEnded.name) {
      throw ScheduleStartRejected(scheduleId);
    }
    // An explicit start supplies the new run timestamp; automatic starts do
    // not possess authority to clear a restore confirmation requirement.
    if (existing.requiresStartConfirmation && startedAt == null) {
      throw ScheduleStartRejected(scheduleId);
    }
    final firstStartedAt = (existing.startedAt ?? startedAt ?? _now()).toUtc();
    if (existing.isStarted &&
        existing.startedAt != null &&
        existing.preparationFrozen) {
      return firstStartedAt;
    }
    final evaluationNow = _now().toUtc();
    final time = ScheduleTimeResolver.resolve(
      joined.toScheduleEntity(),
      nowUtc: evaluationNow,
    );
    if (time.instantUtc == null) {
      throw ScheduleStartRejected(scheduleId);
    }
    var selectedOffset = existing.occurrenceOffsetSeconds;
    if (selectedOffset == null) {
      if (time.instantUtc!.isBefore(evaluationNow) ||
          existing.isStarted ||
          existing.preparationFrozen ||
          existing.startedAt != null ||
          time.occurrences.length != 1) {
        throw ScheduleStartRejected(scheduleId);
      }
      selectedOffset = time.occurrences.single.offsetSeconds;
    }
    checkIntent();
    await _scheduleDao.updateSchedule(
      existing.copyWith(
        occurrenceOffsetSeconds: Value(selectedOffset),
        isStarted: true,
        startedAt: Value(firstStartedAt),
        preparationFrozen: true,
      ),
    );
    checkIntent();
    if (existing.requiresStartConfirmation) {
      await (_database.update(
        _database.schedules,
      )..where((t) => t.id.equals(scheduleId))).write(
        const SchedulesCompanion(requiresStartConfirmation: Value(false)),
      );
    }
    checkIntent();
    await _userDao.markDurableDataChanged(localProfileId);
    checkIntent();
    return firstStartedAt;
  });

  @override
  Future<ScheduleEntity> getScheduleById(String id) async {
    return (await _scheduleDao.getScheduleById(id)).toScheduleEntity();
  }

  @override
  Future<List<ScheduleEntity>> getSchedulesByDate(
    DateTime startDate,
    DateTime? endDate,
  ) async {
    await _recurring?.materialize(
      startDate,
      endDate ?? DateTime.utc(9999, 12, 31),
      perSeriesLimit: endDate == null ? 60 : null,
    );
    final rows = await _scheduleDao.getSchedulesByDate(startDate, endDate);
    return rows.map((row) => row.toScheduleEntity()).toList();
  }

  @override
  Future<void> updateSchedule(
    ScheduleEntity schedule, {
    bool includePreparationSource = false,
  }) async {
    await _database.writeTransaction(() async {
      await _scheduleDao.updateScheduleWithPlace(
        schedule.toScheduleWithPlaceRow(),
      );
      // Retain the old content-free identity until the session validator sees
      // this edit. Deleting it would make an invalid run look like a fresh one
      // and allow automatic catch-up. Unchanged timing/shape stays resumable.
      await _userDao.markDurableDataChanged(localProfileId);
    });
  }

  @override
  Future<void> finishSchedule(String scheduleId, int latenessTime) async {
    final generation = LocalDataOperationGate.shared.captureWrite();
    await _database.writeTransaction(() async {
      final existing = await _scheduleDao.getScheduleById(scheduleId);
      if (existing.schedule.doneStatus != ScheduleDoneStatus.notEnded.name) {
        return;
      }

      if (existing.retainedRecurringReference && !existing.schedule.isStarted) {
        throw ScheduleStartRejected(scheduleId);
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
    if (generation == LocalDataOperationGate.shared.generation) {
      await _clearTimedPreparation(scheduleId);
    }
  }

  Future<void> _clearTimedPreparation(String scheduleId) async {
    try {
      await _timedPreparationRepository.clearTimedPreparation(scheduleId);
    } catch (_) {
      // Active timer state is reconstructible and must not fail durable writes.
    }
  }

  Future<void> dispose() =>
      _disposeFlight ??= _dispose().whenComplete(() => _disposeFlight = null);
  Future<void> _dispose() async {
    _disposed = true;
    LocalDataOperationGate.shared.removeListener(_observeCurrentGeneration);
    _subscriptionOwner = null;
    _subscriptionOwner = null;
    _retiredWatches.retire(_subscription);
    _subscription = null;
    await Future.wait([
      _retiredWatches.close(),
      _subjectClose ??= _scheduleStreamController.close(),
    ]);
  }
}
