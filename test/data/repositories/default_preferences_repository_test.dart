import 'dart:async';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/data/repositories/default_preferences_repository_impl.dart';
import 'package:on_time_front/domain/entities/default_preferences.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/use-cases/default_preferences_workflow.dart';
import 'package:on_time_front/domain/use-cases/load_user_use_case.dart';
import 'package:on_time_front/domain/use-cases/schedule_mutation_alarm_effects_coordinator.dart';
import 'package:on_time_front/presentation/my_page/preparation_spare_time_edit/bloc/default_preparation_spare_time_form_bloc.dart';

PreparationEntity preparation([int minutes = 5]) => PreparationEntity(
  preparationStepList: [
    PreparationStepEntity(
      id: 'step',
      preparationName: 'Pack',
      preparationTime: Duration(minutes: minutes),
    ),
  ],
);

class _Load extends Fake implements LoadUserUseCase {
  int calls = 0;
  Future<void> Function()? handler;
  @override
  Future<void> call() async {
    calls++;
    await handler?.call();
  }
}

class _Effects extends Fake implements ScheduleMutationAlarmEffectsCoordinator {
  int calls = 0;
  Future<bool> Function()? handler;
  @override
  Future<bool> afterCommit() async {
    calls++;
    return await handler?.call() ?? true;
  }
}

class _Barrier extends QueryInterceptor {
  bool armed = false;
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    if (armed && statement.contains('FROM "preparation_users"')) {
      armed = false;
      entered.complete();
      await release.future;
    }
    return executor.runSelect(statement, args);
  }
}

class _AuthorityFault extends QueryInterceptor {
  _AuthorityFault(this.failAt);
  final int failAt;
  bool committedWrite = false;
  int reads = 0;
  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    final result = await executor.runUpdate(statement, args);
    if (statement.contains('data_revision = data_revision + 1')) {
      committedWrite = true;
    }
    return result;
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    if (committedWrite &&
        statement.contains('FROM "users"') &&
        ++reads == failAt) {
      throw StateError('injected authority SELECT failure');
    }
    return executor.runSelect(statement, args);
  }
}

void main() {
  late AppDatabase db;
  late LocalDataOperationGate gate;
  late DefaultPreferencesRepositoryImpl repo;
  late _Load load;
  late _Effects effects;
  late DefaultPreferencesWorkflow workflow;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    gate = LocalDataOperationGate();
    repo = DefaultPreferencesRepositoryImpl(db, gate: gate);
    load = _Load();
    effects = _Effects();
    workflow = DefaultPreferencesWorkflow(repo, load, effects);
    await db.userDao.putUser(
      const UserEntity(
        id: 'local-profile',
        spareTime: Duration(minutes: 10),
        note: 'retain me',
      ),
    );
    await db.preparationUserDao.createPreparationUser(
      preparation(),
      'local-profile',
    );
    await db
        .into(db.places)
        .insert(
          PlacesCompanion.insert(id: const Value('place'), placeName: 'Office'),
        );
    await db
        .into(db.schedules)
        .insert(
          SchedulesCompanion.insert(
            id: const Value('dependent'),
            placeId: 'place',
            scheduleName: 'Meeting',
            scheduleTime: DateTime.utc(2030),
            moveTime: Duration.zero,
          ),
        );
  });
  tearDown(() async {
    await db.close();
    gate.dispose();
  });
  Future<User> profile() => (db.select(
    db.users,
  )..where((u) => u.id.equals('local-profile'))).getSingle();
  Future<DefaultPreferencesSubmission> input({
    int minutes = 8,
    int spare = 20,
  }) async => DefaultPreferencesSubmission(
    baseline: await repo.read(),
    preparation: preparation(minutes),
    spareTime: Duration(minutes: spare),
  );

  test(
    'atomic pair commits one revision and effect sees both values',
    () async {
      final before = await profile();
      effects.handler = () async {
        expect((await profile()).spareTime, 20);
        expect((await repo.read()).preparation.totalDuration.inMinutes, 8);
        return true;
      };
      final receipt = await workflow.save(await input());
      final after = await profile();
      expect(receipt.complete, isTrue);
      expect(receipt.changed, isTrue);
      expect(after.dataRevision, before.dataRevision + 1);
      expect(after.note, 'retain me');
      expect(effects.calls, 1);
      expect(load.calls, 1);
    },
  );
  for (final target in [
    'DELETE ON preparation_users',
    'INSERT ON preparation_users',
    'UPDATE OF spare_time ON users',
    'UPDATE OF data_revision ON users',
  ]) {
    test(
      '$target fault rolls back pair, revision and dependency metadata',
      () async {
        final before = await profile();
        final schedule = await db.select(db.schedules).getSingle();
        final old = await repo.read();
        await db.customStatement(
          "CREATE TRIGGER injected BEFORE $target BEGIN SELECT RAISE(ABORT,'private fault path'); END",
        );
        await expectLater(
          workflow.save(await input()),
          throwsA(
            isA<DefaultPreferencesRejected>().having(
              (e) => e.failure,
              'failure',
              DefaultPreferencesFailure.failed,
            ),
          ),
        );
        expect(await profile(), before);
        expect((await repo.read()).preparation, old.preparation);
        expect(await db.select(db.schedules).getSingle(), schedule);
        expect(effects.calls, 0);
        expect(load.calls, 0);
      },
    );
  }
  test('no-op does not touch rows, dependencies, revision or effects', () async {
    final before = await profile();
    final schedule = await db.select(db.schedules).getSingle();
    await db.customStatement(
      "CREATE TRIGGER reject_any BEFORE DELETE ON preparation_users BEGIN SELECT RAISE(ABORT,'must not write'); END",
    );
    final receipt = await workflow.save(await input(minutes: 5, spare: 10));
    expect(receipt.changed, isFalse);
    expect(receipt.complete, isTrue);
    expect(await profile(), before);
    expect(await db.select(db.schedules).getSingle(), schedule);
    expect(load.calls, 0);
    expect(effects.calls, 0);
  });
  test(
    'spare-only leaves preparation and dependent aggregate version intact',
    () async {
      final schedule = await db.select(db.schedules).getSingle();
      await db.customStatement(
        "CREATE TRIGGER reject_any BEFORE DELETE ON preparation_users BEGIN SELECT RAISE(ABORT,'must not rewrite preparation'); END",
      );
      await workflow.save(await input(minutes: 5));
      expect((await profile()).spareTime, 20);
      expect(await db.select(db.schedules).getSingle(), schedule);
    },
  );
  test(
    'default change invalidates dependents but preserves frozen owned history',
    () async {
      await db
          .into(db.preparationDefinitions)
          .insert(
            PreparationDefinitionsCompanion.insert(
              id: 'owned',
              ownerId: 'frozen',
              scope: 'schedule',
              name: 'Frozen',
              createdAt: DateTime.utc(2026),
            ),
          );
      await db
          .into(db.preparationDefinitionSteps)
          .insert(
            PreparationDefinitionStepsCompanion.insert(
              id: 'step',
              definitionId: 'owned',
              name: 'Original',
              minutes: 12,
              position: 0,
            ),
          );
      await db
          .into(db.schedules)
          .insert(
            SchedulesCompanion.insert(
              id: const Value('frozen'),
              placeId: 'place',
              scheduleName: 'History',
              scheduleTime: DateTime.utc(2025),
              moveTime: Duration.zero,
              preparationDefinitionId: const Value('owned'),
              preparationFrozen: const Value(true),
              startedAt: Value(DateTime.utc(2025)),
              finishedAt: Value(DateTime.utc(2025, 1, 1, 1)),
              doneStatus: const Value('onTime'),
              scoreContributionRecorded: const Value(true),
            ),
          );
      final before = await db.select(db.schedules).get();
      final owned = await db.select(db.preparationDefinitionSteps).get();
      await workflow.save(await input());
      final after = await db.select(db.schedules).get();
      expect(
        after.firstWhere((s) => s.id == 'frozen'),
        before.firstWhere((s) => s.id == 'frozen'),
      );
      expect(
        after.firstWhere((s) => s.id == 'dependent').aggregateVersion,
        greaterThan(
          before.firstWhere((s) => s.id == 'dependent').aggregateVersion!,
        ),
      );
      expect(await db.select(db.preparationDefinitionSteps).get(), owned);
    },
  );
  test(
    'reload failure keeps commit and retries only reload, even using old receipt',
    () async {
      load.handler = () async => throw StateError('sensitive read failure');
      final command = await input();
      final receipt = await workflow.save(command);
      final after = await profile();
      expect(receipt.reloadPending, isTrue);
      expect(receipt.deliveryPending, isFalse);
      expect(effects.calls, 1);
      load.handler = null;
      expect((await workflow.retry(receipt)).complete, isTrue);
      expect((await workflow.retry(receipt)).complete, isTrue);
      expect((await workflow.save(command)).complete, isTrue);
      expect(await profile(), after);
      expect(load.calls, 2);
      expect(effects.calls, 1);
    },
  );
  test(
    'delivery failure retries only delivery and cannot restore old preferences',
    () async {
      effects.handler = () async => false;
      final receipt = await workflow.save(await input());
      await workflow.save(await input(minutes: 15, spare: 30));
      final after = await profile();
      effects.handler = () async {
        expect((await profile()).spareTime, 30);
        return true;
      };
      expect((await workflow.retry(receipt)).complete, isTrue);
      expect(await profile(), after);
      expect(load.calls, 2);
    },
  );
  test('duplicate submit and retry share actual pending Future', () async {
    final release = Completer<void>();
    load.handler = () => release.future;
    final command = await input();
    final first = workflow.save(command);
    final second = workflow.save(command);
    expect(identical(first, second), isTrue);
    release.complete();
    final receipt = await first;
    expect(load.calls, 1);
    expect(effects.calls, 1);
    final after = await profile();
    await workflow.retry(receipt);
    expect(await profile(), after);
  });
  test(
    'restore generation after commit stops remaining effects and marks superseded',
    () async {
      load.handler = () => gate.run(() async {}, replacesData: true);
      final receipt = await workflow.save(await input());
      final after = await profile();
      expect(receipt.changed, isTrue);
      expect(receipt.superseded, isTrue);
      expect(receipt.deliveryPending, isTrue);
      expect(effects.calls, 0);
      expect((await workflow.retry(receipt)).superseded, isTrue);
      expect(await profile(), after);
    },
  );
  for (final change in ['revision', 'store', 'generation', 'pending']) {
    test(
      '$change invalidates loaded baseline without mutation or effects',
      () async {
        final command = await input();
        if (change == 'revision') {
          await db.userDao.markDurableDataChanged('local-profile');
        }
        if (change == 'store') {
          await db
              .update(db.users)
              .write(
                const UsersCompanion(storeIncarnation: Value('different')),
              );
        }
        if (change == 'generation') {
          await gate.run(() async {}, replacesData: true);
        }
        if (change == 'pending') gate.setRecoveryPending(true);
        final before = await profile();
        await expectLater(
          workflow.save(command),
          throwsA(isA<DefaultPreferencesRejected>()),
        );
        expect(await profile(), before);
        expect(effects.calls, 0);
        expect(load.calls, 0);
        expect(
          (await db.preparationUserDao.getPreparationUsersByUserId(
            'local-profile',
          )).totalDuration.inMinutes,
          5,
        );
      },
    );
  }
  test(
    'stale identical values still conflict and ABA revision cannot be rebased',
    () async {
      final command = await input(minutes: 5, spare: 10);
      await db.userDao.updateSpareTime(
        'local-profile',
        const Duration(minutes: 15),
      );
      await db.userDao.updateSpareTime(
        'local-profile',
        const Duration(minutes: 10),
      );
      await expectLater(
        workflow.save(command),
        throwsA(
          isA<DefaultPreferencesRejected>().having(
            (e) => e.failure,
            'failure',
            DefaultPreferencesFailure.conflict,
          ),
        ),
      );
    },
  );
  for (final spare in [0, 3, 9, 1440]) {
    test('valid $spare minute preference is preserved exactly', () async {
      await workflow.save(await input(spare: spare));
      expect((await profile()).spareTime, spare);
    });
  }
  test('empty default is legal', () async {
    final receipt = await workflow.save(
      DefaultPreferencesSubmission(
        baseline: await repo.read(),
        preparation: const PreparationEntity(preparationStepList: []),
        spareTime: Duration.zero,
      ),
    );
    expect(receipt.complete, isTrue);
    expect((await repo.read()).preparation.preparationStepList, isEmpty);
  });

  for (final kind in [
    'duplicate',
    'dangling',
    'cycle',
    'split',
    'name',
    'minutes',
    'subminute',
    'spare',
  ]) {
    test(
      '$kind invalid input is rejected before any durable mutation',
      () async {
        final step = preparation().preparationStepList.single;
        final steps = switch (kind) {
          'duplicate' => [step, step],
          'dangling' => [step.copyWith(nextPreparationId: 'missing')],
          'cycle' => [step.copyWith(nextPreparationId: 'step')],
          'split' => [
            step.copyWith(nextPreparationId: 'two'),
            step.copyWith(id: 'two'),
            step.copyWith(id: 'three'),
          ],
          'name' => [step.copyWith(preparationName: '   ')],
          'minutes' => [step.copyWith(preparationTime: Duration.zero)],
          'subminute' => [
            step.copyWith(preparationTime: const Duration(seconds: 61)),
          ],
          _ => [step],
        };
        final before = await profile();
        await expectLater(
          workflow.save(
            DefaultPreferencesSubmission(
              baseline: await repo.read(),
              preparation: PreparationEntity(preparationStepList: steps),
              spareTime: kind == 'spare'
                  ? const Duration(minutes: 1441)
                  : const Duration(minutes: 20),
            ),
          ),
          throwsA(
            isA<DefaultPreferencesRejected>().having(
              (e) => e.failure,
              'failure',
              DefaultPreferencesFailure.invalid,
            ),
          ),
        );
        expect(await profile(), before);
        expect((await repo.read()).preparation, preparation());
        expect(effects.calls, 0);
      },
    );
  }
  test(
    'omitted links use supplied list order; explicit split chains are invalid',
    () async {
      final first = preparation().preparationStepList.single;
      await workflow.save(
        DefaultPreferencesSubmission(
          baseline: await repo.read(),
          preparation: PreparationEntity(
            preparationStepList: [
              first,
              first.copyWith(id: 'two', preparationName: 'Second'),
            ],
          ),
          spareTime: const Duration(minutes: 10),
        ),
      );
      final steps = (await repo.read()).preparation.preparationStepList;
      expect(steps.map((s) => s.id), ['step', 'two']);
      expect(steps.first.nextPreparationId, 'two');
      final before = await profile();
      await workflow.save(
        DefaultPreferencesSubmission(
          baseline: await repo.read(),
          preparation: PreparationEntity(
            preparationStepList: [
              first,
              first.copyWith(id: 'two', preparationName: 'Second'),
            ],
          ),
          spareTime: const Duration(minutes: 10),
        ),
      );
      expect(await profile(), before);
    },
  );
  test(
    'a step ID owned by another profile rolls back the default replacement',
    () async {
      await db.userDao.putUser(
        const UserEntity(id: 'other', spareTime: Duration.zero, note: ''),
      );
      await db.preparationUserDao.createPreparationUser(
        PreparationEntity(
          preparationStepList: [
            preparation().preparationStepList.single.copyWith(id: 'foreign'),
          ],
        ),
        'other',
      );
      final before = await profile();
      await expectLater(
        workflow.save(
          DefaultPreferencesSubmission(
            baseline: await repo.read(),
            preparation: PreparationEntity(
              preparationStepList: [
                preparation().preparationStepList.single.copyWith(
                  id: 'foreign',
                ),
              ],
            ),
            spareTime: const Duration(minutes: 20),
          ),
        ),
        throwsA(
          isA<DefaultPreferencesRejected>().having(
            (e) => e.failure,
            'failure',
            DefaultPreferencesFailure.failed,
          ),
        ),
      );
      expect(await profile(), before);
      expect((await repo.read()).preparation, preparation());
      expect(
        (await db.preparationUserDao.getPreparationUsersByUserId(
          'other',
        )).preparationStepList.single.id,
        'foreign',
      );
    },
  );
  test(
    'actual Bloc preserves edits and reports saved reload-only pending',
    () async {
      load.handler = () async => throw StateError('not for UI');
      final bloc = DefaultPreparationSpareTimeFormBloc(workflow);
      addTearDown(bloc.close);
      bloc.add(const FormEditRequested());
      await bloc.stream.firstWhere(
        (s) => s.status == DefaultPreparationSpareTimeStatus.success,
      );
      bloc.add(const SpareTimeIncreased());
      await bloc.stream.firstWhere(
        (s) => s.spareTime == const Duration(minutes: 15),
      );
      bloc.add(FormSubmitted(preparation: preparation(8)));
      await bloc.stream.firstWhere(
        (s) => s.status == DefaultPreparationSpareTimeStatus.followUpPending,
      );
      final after = await profile();
      expect(bloc.state.receipt!.reloadPending, isTrue);
      expect(bloc.state.canSubmit, isFalse);
      load.handler = null;
      bloc.add(const FormFollowUpRetried());
      await bloc.stream.firstWhere(
        (s) => s.status == DefaultPreparationSpareTimeStatus.submitted,
      );
      expect(await profile(), after);
      expect(effects.calls, 1);
    },
  );
  for (final faultAt in [1, 3]) {
    test(
      'postcommit authority SELECT $faultAt failure retains commit and retries without repeating successful effects',
      () async {
        final fault = _AuthorityFault(faultAt);
        final other = AppDatabase.forTesting(
          NativeDatabase.memory().interceptWith(fault),
        );
        try {
          await other.userDao.putUser(
            const UserEntity(
              id: 'local-profile',
              spareTime: Duration(minutes: 10),
              note: '',
            ),
          );
          await other.preparationUserDao.createPreparationUser(
            preparation(),
            'local-profile',
          );
          final repository = DefaultPreferencesRepositoryImpl(
            other,
            gate: gate,
          );
          final flow = DefaultPreferencesWorkflow(repository, load, effects);
          final receipt = await flow.save(
            DefaultPreferencesSubmission(
              baseline: await repository.read(),
              preparation: preparation(8),
              spareTime: const Duration(minutes: 20),
            ),
          );
          expect(receipt.authorityPending, isTrue);
          expect(receipt.superseded, isFalse);
          expect(receipt.complete, isFalse);
          expect(load.calls, faultAt == 1 ? 0 : 1);
          expect(effects.calls, faultAt == 1 ? 0 : 1);
          final after = await other.select(other.users).getSingle();
          expect(after.dataRevision, 1);
          expect(after.spareTime, 20);
          final retry = await flow.retry(receipt);
          expect(retry.complete, isTrue);
          expect(load.calls, 1);
          expect(effects.calls, 1);
          expect(await other.select(other.users).getSingle(), after);
        } finally {
          await other.close();
        }
      },
    );
  }
  test(
    'same-generation pending cleanup is unavailable and allows read-only follow-up retry',
    () async {
      load.handler = () async {
        gate.setRecoveryPending(true);
      };
      final receipt = await workflow.save(await input());
      final after = await profile();
      expect(receipt.authorityPending, isTrue);
      expect(receipt.superseded, isFalse);
      expect(effects.calls, 0);
      gate.setRecoveryPending(false);
      expect((await workflow.retry(receipt)).complete, isTrue);
      expect(load.calls, 1);
      expect(effects.calls, 1);
      expect(await profile(), after);
    },
  );
  test(
    'failed replacement still expires old operation without claiming replacement committed',
    () async {
      effects.handler = () async => false;
      final receipt = await workflow.save(await input());
      final after = await profile();
      await expectLater(
        gate.run(() async {
          throw StateError('replacement transaction rolled back');
        }, replacesData: true),
        throwsStateError,
      );
      final retry = await workflow.retry(receipt);
      expect(retry.superseded, isTrue);
      expect(retry.authorityPending, isFalse);
      expect(load.calls, 1);
      expect(effects.calls, 1);
      expect(await profile(), after);
    },
  );
  test(
    'coherent read excludes concurrent edit between profile and preparation reads',
    () async {
      final barrier = _Barrier();
      final other = AppDatabase.forTesting(
        NativeDatabase.memory().interceptWith(barrier),
      );
      try {
        await other.userDao.putUser(
          const UserEntity(
            id: 'local-profile',
            spareTime: Duration(minutes: 10),
            note: '',
          ),
        );
        await other.preparationUserDao.createPreparationUser(
          preparation(),
          'local-profile',
        );
        final reader = DefaultPreferencesRepositoryImpl(other, gate: gate);
        barrier.armed = true;
        final reading = reader.read();
        await barrier.entered.future;
        final writing = other.writeTransaction(() async {
          await other.preparationUserDao.createPreparationUser(
            preparation(12),
            'local-profile',
          );
          await other.userDao.updateSpareTime(
            'local-profile',
            const Duration(minutes: 30),
          );
        }, gate: gate);
        barrier.release.complete();
        final snapshot = await reading;
        await writing;
        expect(snapshot.spareTime, const Duration(minutes: 10));
        expect(snapshot.preparation.totalDuration.inMinutes, 5);
        expect(snapshot.revision, 0);
        expect((await reader.read()).spareTime, const Duration(minutes: 30));
      } finally {
        await other.close();
      }
    },
  );
  test(
    'generation change during a delayed read rejects its old snapshot',
    () async {
      final barrier = _Barrier();
      final other = AppDatabase.forTesting(
        NativeDatabase.memory().interceptWith(barrier),
      );
      try {
        await other.userDao.putUser(
          const UserEntity(
            id: 'local-profile',
            spareTime: Duration.zero,
            note: '',
          ),
        );
        final reader = DefaultPreferencesRepositoryImpl(other, gate: gate);
        barrier.armed = true;
        final reading = reader.read();
        final failure = expectLater(
          reading,
          throwsA(isA<LocalDataUnavailable>()),
        );
        await barrier.entered.future;
        await gate.run(() async {}, replacesData: true);
        barrier.release.complete();
        await failure;
      } finally {
        await other.close();
      }
    },
  );
}
