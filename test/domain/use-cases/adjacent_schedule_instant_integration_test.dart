import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/time/schedule_time_resolution.dart';
import 'package:on_time_front/data/data_sources/preparation_local_data_source.dart';
import 'package:on_time_front/data/repositories/preparation_repository_impl.dart';
import 'package:on_time_front/data/repositories/schedule_repository_impl.dart';
import 'package:on_time_front/data/repositories/user_repository_impl.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/repositories/timed_preparation_repository.dart';
import 'package:on_time_front/domain/use-cases/get_adjacent_schedules_with_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_schedules_by_date_use_case.dart';

// Actual SQLite, public schedule/preparation writers and range streams. This is
// not an OS notification or native-device test.
void main() {
  late AppDatabase database;
  late ScheduleRepositoryImpl schedules;
  late UserRepositoryImpl users;
  late PreparationRepositoryImpl preparations;
  late GetAdjacentSchedulesWithPreparationUseCase adjacent;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.userDao.putUser(
      const UserEntity(
        id: 'local-profile',
        spareTime: Duration(minutes: 60),
        note: '',
        isOnboardingCompleted: true,
      ),
    );
    schedules = ScheduleRepositoryImpl(
      database: database,
      timedPreparationRepository: _UnusedRuntime(),
    );
    users = UserRepositoryImpl(database);
    preparations = PreparationRepositoryImpl(
      preparationLocalDataSource: PreparationLocalDataSourceImpl(
        appDatabase: database,
      ),
      userRepository: users,
      database: database,
    );
    adjacent = GetAdjacentSchedulesWithPreparationUseCase(
      GetSchedulesByDateUseCase(schedules),
      GetPreparationByScheduleIdUseCase(preparations),
    );
  });

  tearDown(() async {
    await preparations.dispose();
    await users.dispose();
    await schedules.dispose();
    await database.close();
  });

  Future<void> create(
    String id,
    DateTime civil,
    String zone,
    int offset,
  ) async {
    await schedules.createSchedule(
      ScheduleEntity(
        id: id,
        place: PlaceEntity(id: 'place-$id', placeName: 'Office'),
        scheduleName: id,
        scheduleTime: civil,
        timeZoneId: zone,
        occurrenceOffsetSeconds: offset,
        moveTime: const Duration(minutes: 2),
        isChanged: false,
        isStarted: false,
        scheduleSpareTime: null,
        scheduleNote: '',
      ),
    );
    await preparations.createCustomPreparation(
      PreparationEntity(
        preparationStepList: [
          PreparationStepEntity(
            id: 'step-$id',
            preparationName: 'Prepare',
            preparationTime: const Duration(minutes: 5),
          ),
        ],
      ),
      id,
    );
  }

  Future<void> settle(int count) async {
    await schedules.scheduleStream.firstWhere((value) => value.length == count);
    await preparations.preparationStream.firstWhere(
      (value) => value.length == count,
    );
  }

  Future<List<Map<String, Object?>>> stored() async => [
    for (final row
        in await database
            .customSelect('SELECT * FROM schedules ORDER BY id')
            .get())
      row.data,
    for (final row
        in await database.customSelect('SELECT * FROM users ORDER BY id').get())
      row.data,
  ];

  test(
    'a previous civil day at the same instant is returned as the next conflict candidate',
    () async {
      // New York is still January 1, while the selected occurrence is January 2 UTC.
      await create(
        'same-instant',
        DateTime.utc(2030, 1, 1, 19, 15),
        'America/New_York',
        -18000,
      );
      await create(
        'previous',
        DateTime.utc(2030, 1, 2, 9, 14),
        'Asia/Seoul',
        32400,
      );
      await create('later', DateTime.utc(2030, 1, 2, 1), 'UTC', 0);
      await settle(3);
      final before = await stored();
      final result = await adjacent(
        selectedDateTime: DateTime.utc(2030, 1, 2, 0, 15),
        startDate: DateTime.utc(2030, 1, 2),
        endDate: DateTime.utc(2030, 1, 3),
      );
      expect(result.nextSchedule?.id, 'same-instant');
      expect(
        result.nextSchedule?.occurrenceInstantUtc,
        DateTime.utc(2030, 1, 2, 0, 15),
      );
      expect(
        result.nextSchedule?.preparationStartTime,
        DateTime.utc(2030, 1, 2, 0, 8),
      );
      expect(result.previousSchedule?.id, 'previous');
      expect(
        result.previousSchedule?.occurrenceInstantUtc,
        DateTime.utc(2030, 1, 2, 0, 14),
      );
      expect(
        result.nextSchedule?.scheduleTime,
        DateTime.utc(2030, 1, 1, 19, 15),
      );
      expect(await stored(), before);
    },
  );

  test(
    'UTC plus14 selected civil includes the same instant two civil dates earlier at minus11',
    () async {
      await create(
        'self-east',
        DateTime.utc(2030, 1, 2, 0, 30),
        'Pacific/Kiritimati',
        50400,
      );
      await create(
        'same-west',
        DateTime.utc(2029, 12, 31, 23, 30),
        'Pacific/Pago_Pago',
        -39600,
      );
      await create(
        'later-east',
        DateTime.utc(2030, 1, 2, 0, 31),
        'Pacific/Kiritimati',
        50400,
      );
      await settle(3);
      final before = await stored();
      final raw = await schedules.getScheduleById('same-west');
      final time = ScheduleTimeResolver.resolve(
        raw,
        nowUtc: DateTime.utc(2026),
      );
      expect(
        time.status,
        ScheduleTimeResolutionStatus.resolved,
        reason: 'Fixture zone must exist and match its explicit offset',
      );
      final range = await schedules
          .watchSchedulesByDate(
            DateTime.utc(2029, 12, 31),
            DateTime.utc(2030, 1, 5),
          )
          .first;
      expect(
        range.map((row) => row.id),
        contains('same-west'),
        reason: 'Actual expanded civil query must include fixture',
      );
      final result = await adjacent(
        selectedDateTime: DateTime.utc(2030, 1, 1, 10, 30),
        currentScheduleId: 'self-east',
        startDate: DateTime.utc(2030, 1, 2),
        endDate: DateTime.utc(2030, 1, 3),
      );
      expect(result.nextSchedule?.id, 'same-west');
      expect(
        result.nextSchedule?.occurrenceInstantUtc,
        DateTime.utc(2030, 1, 1, 10, 30),
      );
      expect(
        result.nextSchedule?.scheduleTime,
        DateTime.utc(2029, 12, 31, 23, 30),
      );
      expect(await stored(), before);
    },
  );

  test(
    'opposite civil-date ordering and self exclusion use actual occurrence instants',
    () async {
      await create('self', DateTime.utc(2030, 1, 2, 0, 15), 'UTC', 0);
      await create(
        'earlier',
        DateTime.utc(2030, 1, 2, 9, 14),
        'Asia/Seoul',
        32400,
      );
      await create(
        'later',
        DateTime.utc(2030, 1, 1, 19, 16),
        'America/New_York',
        -18000,
      );
      await settle(3);
      final before = await stored();
      final result = await adjacent(
        selectedDateTime: DateTime.utc(2030, 1, 2, 0, 15),
        currentScheduleId: 'self',
        startDate: DateTime.utc(2030, 1, 2),
        endDate: DateTime.utc(2030, 1, 3),
      );
      expect(result.previousSchedule?.id, 'earlier');
      expect(result.nextSchedule?.id, 'later');
      expect(
        result.previousSchedule!.scheduleTime.isAfter(
          result.nextSchedule!.scheduleTime,
        ),
        isTrue,
      );
      expect(
        result.previousSchedule!.occurrenceInstantUtc.isBefore(
          result.nextSchedule!.occurrenceInstantUtc,
        ),
        isTrue,
      );
      expect(await stored(), before);
    },
  );
}

class _UnusedRuntime implements TimedPreparationRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Adjacent lookup must not read transient runtime.');
}
