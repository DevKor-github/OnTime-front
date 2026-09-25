import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/backup_operation.dart';

void main() {
  test(
    'unknown authority cannot be constructed with terminal or arbitrary failure state',
    () {
      for (final pending in [true, false]) {
        expect(
          () => BackupRestoreReceipt(
            disposition: BackupCommitDisposition.undetermined,
            generation: 1,
            followUpPending: pending,
            failure: DataOperationFailure.failed,
          ),
          throwsArgumentError,
        );
      }
      const unknown = BackupRestoreReceipt.uncertain(generation: 1);
      expect(unknown.followUpPending, true);
      expect(unknown.committed, null);
      expect(unknown.failure, null);
      expect(unknown.recoveryFollowUp, null);
    },
  );
  test('recovery phase receipts always mean committed and unfinished', () {
    for (final phase in RecoveryFollowUp.values) {
      final receipt = BackupRestoreReceipt.recovery(
        generation: 1,
        phase: phase,
      );
      expect(receipt.disposition, BackupCommitDisposition.committed);
      expect(receipt.followUpPending, true);
      expect(receipt.failure, null);
    }
  });
}
