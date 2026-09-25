import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/data/daos/schedule_dao.dart';
import 'package:on_time_front/data/mappers/domain_persistence_mappers.dart';
import 'package:on_time_front/data/repositories/schedule_repository_impl.dart';
import 'package:on_time_front/data/tables/schedule_with_place_model.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/repositories/timed_preparation_repository.dart';

void main() {
  for (final scenario in ['replace', 'pending-resume', 'rollback']) {
    test(
      'old same-ID watch cannot overwrite fresh subscription after $scenario',
      () async {
        final db = _WatchDb();
        addTearDown(db.close);
        final gate = LocalDataOperationGate.shared;
        final seed = ScheduleEntity(
          id: 'same',
          place: const PlaceEntity(id: 'place', placeName: 'Home'),
          scheduleName: 'old',
          scheduleTime: DateTime(2030),
          moveTime: Duration.zero,
          isChanged: false,
          isStarted: false,
          scheduleSpareTime: Duration.zero,
          scheduleNote: '',
        );
        await db.scheduleDao.createSchedule(seed.toScheduleWithPlaceRow());
        final old = await db.scheduleDao.getScheduleById('same');
        final repository = ScheduleRepositoryImpl(
          database: db,
          timedPreparationRepository: _Timed(),
        );
        addTearDown(repository.dispose);
        final seen = <String>[];
        final subscription = repository.scheduleStream.listen((rows) {
          if (rows.isNotEmpty) seen.add(rows.single.scheduleName);
        });
        addTearDown(subscription.cancel);
        await pumpEventQueue();
        expect(db.latches, hasLength(1));
        if (scenario == 'pending-resume') {
          gate.setRecoveryPending(true);
          await db.customStatement("UPDATE schedules SET schedule_name='new'");
          gate.setRecoveryPending(false);
        } else if (scenario == 'rollback') {
          await expectLater(
            gate.run(
              () => db.transaction(() async {
                await db.customStatement(
                  "UPDATE schedules SET schedule_name='must rollback'",
                );
                throw StateError('injected replacement rollback');
              }),
              replacesData: true,
            ),
            throwsStateError,
          );
        } else {
          await gate.run(
            () =>
                db.customStatement("UPDATE schedules SET schedule_name='new'"),
            replacesData: true,
          );
        }
        await pumpEventQueue();
        expect(db.latches, hasLength(2));
        final fresh = await db.scheduleDao.getScheduleById('same');
        db.latches[1].complete([fresh]);
        await pumpEventQueue();
        expect(seen.last, scenario == 'rollback' ? 'old' : 'new');
        final emissions = seen.length;
        db.latches[0].complete([old]);
        await pumpEventQueue();
        expect(seen, hasLength(emissions));
        expect(seen.last, scenario == 'rollback' ? 'old' : 'new');
      },
    );
  }
}

class _WatchDb extends AppDatabase {
  _WatchDb() : super.forTesting(NativeDatabase.memory());
  final latches = <Completer<List<ScheduleWithPlace>>>[];
  late final ScheduleDao _dao = _WatchDao(this);
  @override
  ScheduleDao get scheduleDao => _dao;
}

class _WatchDao extends ScheduleDao {
  _WatchDao(this.owner) : super(owner);
  final _WatchDb owner;
  @override
  Stream<List<ScheduleWithPlace>> watchScheduleList() async* {
    final latch = Completer<List<ScheduleWithPlace>>();
    owner.latches.add(latch);
    yield await latch.future;
  }
}

class _Timed implements TimedPreparationRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
