import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/core/startup/startup_dependency_scope.dart';
import 'package:on_time_front/domain/repositories/preparation_repository.dart';
import 'package:on_time_front/domain/repositories/schedule_repository.dart';
import 'package:on_time_front/domain/repositories/user_repository.dart';
import 'package:on_time_front/presentation/app/bloc/schedule/schedule_bloc.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'production registrations close real repository watches and Drift before a replacement graph',
    () async {
      final container = GetIt.I;
      expect(container.currentScopeName, 'baseScope');
      for (var attempt = 0; attempt < 2; attempt++) {
        final owner = StartupDependencyScope(container);
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        final oldSkip = container.skipDoubleRegistration;
        var closes = 0;
        void register() {
          StartupDependencyScope.own(database, () async {
            await database.close();
            closes++;
          });
          container.registerSingleton<AppDatabase>(
            database,
            dispose: (value) =>
                StartupDependencyScope.release(value, value.close),
          );
          // Only the database port is substituted. Every generated registration,
          // repository, use case and startup singleton executes production code.
          // The skipped product LazyDatabase is owned too and is never opened.
          container.skipDoubleRegistration = true;
          try {
            configureDependencies();
          } finally {
            container.skipDoubleRegistration = oldSkip;
          }
          if (attempt == 0) throw StateError('injected registration failure');
        }

        if (attempt == 0) {
          expect(() => owner.configure(register), throwsStateError);
        } else {
          owner.configure(register);
        }
        final user = container<UserRepository>();
        final preparation = container<PreparationRepository>();
        final schedule = container<ScheduleRepository>();
        final bloc = container<ScheduleBloc>();
        final done = List.generate(3, (_) => Completer<void>());
        var emissions = 0;
        final subscriptions = <StreamSubscription<dynamic>>[
          user.userStream.listen((_) => emissions++, onDone: done[0].complete),
          preparation.preparationStream.listen(
            (_) => emissions++,
            onDone: done[1].complete,
          ),
          schedule.scheduleStream.listen(
            (_) => emissions++,
            onDone: done[2].complete,
          ),
        ];
        await user.getUser();
        await database
            .customSelect('SELECT count(*) AS n FROM users')
            .getSingle();
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(emissions, greaterThanOrEqualTo(3));
        // The first graph actually threw after registration; both owners close
        // their real graph before a subsequent attempt can start.
        await owner.cleanup();
        await Future.wait(done.map((entry) => entry.future));
        expect(closes, 1);
        expect(bloc.isClosed, true);
        expect(owner.cleanupComplete, true);
        expect(container.isRegistered<UserRepository>(), false);
        await expectLater(
          database.customSelect('SELECT 1').get(),
          throwsStateError,
        );
        final afterCleanup = emissions;
        LocalDataOperationGate.shared.setRecoveryPending(true);
        LocalDataOperationGate.shared.setRecoveryPending(false);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(emissions, afterCleanup);
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      }
      expect(container.currentScopeName, 'baseScope');
    },
  );
}
