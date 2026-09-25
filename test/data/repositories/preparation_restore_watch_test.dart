import 'dart:async';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/data/data_sources/preparation_local_data_source.dart';
import 'package:on_time_front/data/mappers/domain_persistence_mappers.dart';
import 'package:on_time_front/data/repositories/preparation_repository_impl.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/repositories/user_repository.dart';
import 'package:on_time_front/domain/use-cases/get_preparation_by_schedule_id_use_case.dart';

void main() {
  for (final scenario in ['replacement', 'pending-resume', 'rollback']) {
    test(
      'preparation consumer resumes after $scenario without another write',
      () async {
        final fixture = await _Fixture.create();
        addTearDown(fixture.close);
        final gate = LocalDataOperationGate.shared;
        expect(_name(await fixture.consumer('same')), 'old');
        if (scenario == 'rollback') {
          await expectLater(
            gate.run(
              () => fixture.db.transaction(() async {
                await fixture.rename('rolled back');
                throw StateError('injected rollback');
              }),
              replacesData: true,
            ),
            throwsStateError,
          );
        } else if (scenario == 'pending-resume') {
          gate.setRecoveryPending(true);
          await fixture.rename('new');
          await pumpEventQueue();
          expect(await fixture.repository.preparationStream.first, isEmpty);
          gate.setRecoveryPending(false);
        } else {
          await gate.run(() async {
            gate.setRecoveryPending(true);
            await fixture.rename('new');
          }, replacesData: true);
          await pumpEventQueue();
          expect(await fixture.repository.preparationStream.first, isEmpty);
          gate.setRecoveryPending(false);
        }
        expect(
          _name(
            await fixture.consumer('same').timeout(const Duration(seconds: 5)),
          ),
          scenario == 'rollback' ? 'old' : 'new',
        );
      },
    );
  }
  for (final fails in [false, true]) {
    test(
      'retired preparation read ${fails ? 'error' : 'value'} cannot publish after replacement',
      () async {
        final fixture = await _Fixture.create(latch: true);
        addTearDown(fixture.close);
        await fixture.source.entered.future;
        final errors = <Object>[];
        final seen = <String>[];
        final sub = fixture.repository.preparationStream.listen((map) {
          if (map['same'] != null) seen.add(_name(map['same']!));
        }, onError: errors.add);
        addTearDown(sub.cancel);
        final gate = LocalDataOperationGate.shared;
        final replacement = gate.run(
          () => fixture.rename('new'),
          replacesData: true,
        );
        await pumpEventQueue();
        expect(gate.isReplacingData, isTrue);
        // The old transaction must finish before the replacement can write.
        // Releasing it after token retirement also exercises late failure.
        fixture.source.fail = fails;
        fixture.source.release.complete();
        await replacement;
        expect(
          _name(
            await fixture.consumer('same').timeout(const Duration(seconds: 5)),
          ),
          'new',
        );
        await pumpEventQueue();
        expect(seen, isNot(contains('old')));
        expect(errors, isEmpty);
      },
    );
  }
  test(
    'dispose retires an outstanding preparation query before it completes',
    () async {
      final fixture = await _Fixture.create(latch: true);
      await fixture.source.entered.future;
      final errors = <Object>[];
      final sub = fixture.repository.preparationStream.listen(
        (_) {},
        onError: errors.add,
      );
      final disposal = fixture.repository.dispose();
      fixture.source.fail = true;
      fixture.source.release.complete();
      await disposal;
      await sub.cancel();
      await fixture.db.close();
      expect(errors, isEmpty);
    },
  );
}

String _name(PreparationEntity value) =>
    value.preparationStepList.single.preparationName;

class _Fixture {
  _Fixture(this.db, this.source, this.repository);
  final AppDatabase db;
  final _Source source;
  final PreparationRepositoryImpl repository;
  GetPreparationByScheduleIdUseCase get consumer =>
      GetPreparationByScheduleIdUseCase(repository);
  static Future<_Fixture> create({bool latch = false}) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final schedule = ScheduleEntity(
      id: 'same',
      place: const PlaceEntity(id: 'place', placeName: 'Home'),
      scheduleName: 'Synthetic',
      scheduleTime: DateTime(2030),
      moveTime: Duration.zero,
      isChanged: false,
      isStarted: false,
      scheduleSpareTime: Duration.zero,
      scheduleNote: '',
    );
    await db.scheduleDao.createSchedule(schedule.toScheduleWithPlaceRow());
    await db.preparationScheduleDao.createPreparationSchedule(
      const PreparationEntity(
        preparationStepList: [
          PreparationStepEntity(
            id: 'step',
            preparationName: 'old',
            preparationTime: Duration(minutes: 5),
          ),
        ],
      ),
      'same',
    );
    final source = _Source(db, latch);
    final repo = PreparationRepositoryImpl(
      preparationLocalDataSource: source,
      userRepository: _User(),
      database: db,
    );
    return _Fixture(db, source, repo);
  }

  Future<void> rename(String name) async {
    await (db.update(db.preparationSchedules)
          ..where((t) => t.id.equals('step')))
        .write(PreparationSchedulesCompanion(preparationName: Value(name)));
  }

  Future<void> close() async {
    await repository.dispose();
    LocalDataOperationGate.shared.setRecoveryPending(false);
    await db.close();
  }
}

class _Source extends PreparationLocalDataSourceImpl {
  _Source(AppDatabase db, this.pause) : super(appDatabase: db);
  bool pause;
  bool fail = false;
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<PreparationEntity> getPreparationByScheduleId(String id) async {
    final value = await super.getPreparationByScheduleId(id);
    if (pause) {
      pause = false;
      entered.complete();
      await release.future;
      if (fail) throw StateError('retired synthetic read');
    }
    return value;
  }
}

class _User implements UserRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
