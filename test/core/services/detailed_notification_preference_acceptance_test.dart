import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/services/detailed_notification_preference_service.dart';

// Real SQLite and transaction rollback; not a mobile encryption receipt.
class _AfterPreferenceUpdate extends QueryInterceptor {
  bool armed = false;
  bool holdRead = false;
  final readEntered = Completer<void>(), readRelease = Completer<void>();
  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    final result = await executor.runSelect(statement, args);
    if (holdRead && statement.contains('FROM "users"')) {
      holdRead = false;
      readEntered.complete();
      await readRelease.future;
    }
    return result;
  }

  final entered = Completer<void>();
  final release = Completer<void>();

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    final result = await executor.runUpdate(statement, args);
    if (armed && statement.contains('detailed_notification_content')) {
      armed = false;
      entered.complete();
      await release.future;
    }
    return result;
  }
}

void main() {
  late AppDatabase db;
  late LocalDataOperationGate gate;
  late DetailedNotificationPreferenceService service;
  late _AfterPreferenceUpdate barrier;

  setUp(() async {
    barrier = _AfterPreferenceUpdate();
    db = AppDatabase.forTesting(NativeDatabase.memory().interceptWith(barrier));
    gate = LocalDataOperationGate();
    service = DetailedNotificationPreferenceService(db, gate: gate);
    await db.customStatement(
      "INSERT INTO users(id,spare_time,note,data_revision,alarms_enabled,"
      "detailed_notification_content) VALUES('local-profile',7,'keep',9,0,1)",
    );
  });
  tearDown(() async {
    if (!barrier.release.isCompleted) barrier.release.complete();
    if (!barrier.readRelease.isCompleted) barrier.readRelease.complete();
    await db.close();
    gate.dispose();
  });

  Future<Map<String, Object?>> durable() async =>
      (await db.customSelect('SELECT * FROM users').getSingle()).data;

  test('read and same-value write preserve actual row and revision', () async {
    final before = await durable();
    final read = await service.read(expectedGeneration: 0);
    expect(read.detailedEnabled, isTrue);
    expect(read.scheduleNotificationsEnabled, isFalse);
    expect(read.generation, 0);
    final same = await service.write(true, expectedGeneration: 0);
    expect(same.detailedEnabled, isTrue);
    expect(await durable(), before);
  });

  test(
    'OFF changes only detailed preference and one durable revision',
    () async {
      final before = await durable();
      final earliest = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final saved = await service.write(false, expectedGeneration: 0);
      expect(saved.detailedEnabled, isFalse);
      expect(saved.scheduleNotificationsEnabled, isFalse);
      final after = await durable();
      expect(after, {
        ...before,
        'detailed_notification_content': 0,
        'data_revision': 10,
        'first_durable_data_at': after['first_durable_data_at'],
        'last_durable_data_at': after['last_durable_data_at'],
      });
      final latest = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      expect(
        after['first_durable_data_at'],
        inInclusiveRange(earliest, latest),
      );
      expect(after['last_durable_data_at'], after['first_durable_data_at']);
      await service.write(false, expectedGeneration: 0);
      expect(await durable(), after);
      expect(
        (await service.read(expectedGeneration: 0)).detailedEnabled,
        isFalse,
      );
    },
  );

  test(
    'missing profile cannot be read or written as confirmed private',
    () async {
      await db.customStatement('DELETE FROM users');
      await expectLater(
        service.read(expectedGeneration: 0),
        throwsA(isA<DetailedNotificationProfileUnavailable>()),
      );
      await expectLater(
        Future.sync(() => service.write(false, expectedGeneration: 0)),
        throwsA(anything),
      );
      expect(await db.select(db.users).get(), isEmpty);
    },
  );

  test(
    'old queued intent rejects after replacement even when gate is free',
    () async {
      final before = await durable();
      final acceptedGeneration = gate.generation;
      await gate.run(() async {}, replacesData: true);
      await expectLater(
        Future.sync(
          () => service.write(false, expectedGeneration: acceptedGeneration),
        ),
        throwsA(isA<LocalDataUnavailable>()),
      );
      expect(await durable(), before);
      expect(
        (await service.read(
          expectedGeneration: gate.generation,
        )).detailedEnabled,
        isTrue,
      );
    },
  );

  test(
    'replacement during actual SQL update rolls back bool and revision',
    () async {
      final before = await durable();
      barrier.armed = true;
      final writing = service.write(false, expectedGeneration: 0);
      final rejected = expectLater(
        writing,
        throwsA(isA<LocalDataUnavailable>()),
      );
      try {
        await Future.any([
          barrier.entered.future,
          writing.then<void>((_) {
            fail('write finished before SQL barrier');
          }),
        ]);
        await gate.run(() async {}, replacesData: true);
      } finally {
        if (!barrier.release.isCompleted) barrier.release.complete();
        await rejected;
      }
      expect(await durable(), before);
    },
  );

  test(
    'a read that already fetched ON cannot publish it into a replacement generation',
    () async {
      barrier.holdRead = true;
      final reading = service.read(expectedGeneration: 0);
      final rejected = expectLater(
        reading,
        throwsA(isA<LocalDataUnavailable>()),
      );
      try {
        await barrier.readEntered.future.timeout(const Duration(seconds: 10));
        await gate.run(() async {}, replacesData: true);
      } finally {
        if (!barrier.readRelease.isCompleted) barrier.readRelease.complete();
        await rejected;
      }
    },
  );

  test(
    'a write waiting for the actual DB transaction lock keeps its original generation',
    () async {
      final before = await durable();
      final entered = Completer<void>(), release = Completer<void>();
      final blocker = db.transaction(() async {
        entered.complete();
        await release.future;
      });
      await entered.future;
      final waiting = service.write(false, expectedGeneration: 0);
      final rejected = expectLater(
        waiting,
        throwsA(isA<LocalDataUnavailable>()),
      );
      try {
        await gate.run(() async {}, replacesData: true);
      } finally {
        release.complete();
        await blocker;
        await rejected;
      }
      expect(await durable(), before);
    },
  );

  test(
    'ordinary OFF persists while export owns a nonreplacement gate',
    () async {
      await gate.run(() async {
        expect(gate.isAvailable, isFalse);
        final saved = await service.write(false, expectedGeneration: 0);
        expect(saved.detailedEnabled, isFalse);
        expect((await durable())['data_revision'], 10);
      });
      expect(
        (await service.read(expectedGeneration: 0)).detailedEnabled,
        isFalse,
      );
    },
  );

  test(
    'cleanup-pending and invalidated installations expose no authority',
    () async {
      final before = await durable();
      gate.setRecoveryPending(true);
      await expectLater(
        service.read(expectedGeneration: 0),
        throwsA(isA<LocalDataUnavailable>()),
      );
      await expectLater(
        Future.sync(() => service.write(false, expectedGeneration: 0)),
        throwsA(isA<LocalDataUnavailable>()),
      );
      gate.setRecoveryPending(false);
      gate.invalidate();
      await expectLater(
        service.read(expectedGeneration: gate.generation),
        throwsA(isA<LocalDataUnavailable>()),
      );
      expect(await durable(), before);
    },
  );
}
