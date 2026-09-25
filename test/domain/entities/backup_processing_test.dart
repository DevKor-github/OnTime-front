import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/backup_processing.dart';

void main() {
  test(
    'cleanup retry waits for the running operation and keeps late cleanup registrations',
    () async {
      final owner = BackupProcessingOwner();
      final lease = owner.acquire()..beginOperation();
      final cleaned = <String>[];
      lease.retainCleanup(() async {
        cleaned.add('native');
      });
      var done = false;
      final retry = owner.retryCleanup().then((_) {
        done = true;
      });
      await Future<void>.delayed(Duration.zero);
      expect(done, false);
      expect(cleaned, isEmpty);
      expect(owner.active, same(lease));
      lease.retainCleanup(() async {
        cleaned.add('snapshot');
      });
      lease.endOperation();
      await retry;
      expect(cleaned, ['native', 'snapshot']);
      expect(owner.active, isNull);
    },
  );
  test(
    'a new cleanup registered while retry is awaiting is not overwritten',
    () async {
      final owner = BackupProcessingOwner();
      final lease = owner.acquire();
      final entered = Completer<void>();
      final unblock = Completer<void>();
      final cleaned = <String>[];
      lease.retainCleanup(() async {
        entered.complete();
        await unblock.future;
        cleaned.add('first');
      });
      final retry = owner.retryCleanup();
      await entered.future;
      lease.retainCleanup(() async {
        cleaned.add('late');
      });
      unblock.complete();
      await retry;
      expect(cleaned, ['first', 'late']);
      expect(owner.active, isNull);
    },
  );
  test(
    'failed action retains owner but other independent cleanup is still attempted',
    () async {
      final owner = BackupProcessingOwner();
      final lease = owner.acquire();
      var attempts = 0;
      var later = 0;
      lease.retainCleanup(() async {
        if (++attempts == 1) throw StateError('close');
      });
      lease.retainCleanup(() async {
        later++;
      });
      await expectLater(owner.retryCleanup(), throwsStateError);
      expect(owner.active, same(lease));
      expect(later, 1);
      await owner.retryCleanup();
      expect(attempts, 2);
      expect(later, 1);
      expect(owner.active, isNull);
    },
  );
  test(
    'release request cannot free lease while nested operations are outstanding',
    () async {
      final owner = BackupProcessingOwner();
      final lease = owner.acquire()
        ..beginOperation()
        ..beginOperation();
      lease.release();
      expect(owner.active, same(lease));
      lease.endOperation();
      expect(owner.active, same(lease));
      lease.endOperation();
      expect(owner.active, isNull);
    },
  );
}
