import 'dart:async';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/data/repositories/user_repository_impl.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';

class _Latch extends QueryInterceptor {
  bool armed = false;
  int reads = 0;
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    final result = await executor.runSelect(statement, args);
    if (armed && statement.contains('FROM "users"') && ++reads == 2) {
      armed = false;
      entered.complete();
      await release.future;
    }
    return result;
  }
}

void main() {
  test(
    'late same-store profile reload cannot overwrite newer observed preferences',
    () async {
      final latch = _Latch();
      final db = AppDatabase.forTesting(
        NativeDatabase.memory().interceptWith(latch),
      );
      await db.userDao.putUser(
        const UserEntity(
          id: 'local-profile',
          spareTime: Duration(minutes: 10),
          note: '',
        ),
      );
      final users = UserRepositoryImpl(db);
      final observed = <int>[];
      final sub = users.userStream.listen((u) {
        if (u.valueOrNull != null) observed.add(u.spareTime.inMinutes);
      });
      addTearDown(() async {
        await sub.cancel();
        await users.dispose();
        await db.close();
      });
      await users.getUser();
      await users.userStream.firstWhere(
        (u) => u.spareTimeOrNull == const Duration(minutes: 10),
      );
      latch.armed = true;
      final reload = users.getUser();
      await latch.entered.future;
      final newObserved = users.userStream.firstWhere(
        (u) => u.spareTimeOrNull == const Duration(minutes: 20),
      );
      await users.updateSpareTime(const Duration(minutes: 20));
      await newObserved;
      latch.release.complete();
      final returned = await reload;
      await Future<void>.delayed(Duration.zero);
      expect(
        returned.spareTime,
        const Duration(minutes: 10),
        reason: 'The one-shot return is the snapshot that call actually read.',
      );
      expect(
        observed.last,
        20,
        reason:
            'The already published newer preference must not be overwritten by an older reload.',
      );
      expect((await users.getUser()).spareTime, const Duration(minutes: 20));
      await users.updateSpareTime(const Duration(minutes: 25));
      await users.userStream.firstWhere(
        (u) => u.spareTimeOrNull == const Duration(minutes: 25),
      );
      expect(
        observed.last,
        25,
        reason:
            'Suppressing stale publication cannot starve later normal reads or watches.',
      );
    },
  );
}
