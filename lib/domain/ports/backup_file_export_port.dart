import 'dart:typed_data';
import 'package:on_time_front/domain/entities/backup_processing.dart';

enum BackupFileExportReceipt { saved, cancelled }

abstract interface class BackupFileExportPort {
  Future<BackupFileExportReceipt> exportStream({
    required Stream<List<int>> encrypted,
    required String suggestedName,
    BackupProcessingLease? lease,
  });
}

/// Explicit memory adapter for small callers/tests; product exports use streams.
extension MemoryBackupExport on BackupFileExportPort {
  Future<BackupFileExportReceipt> export({
    required Uint8List encryptedBytes,
    required String suggestedName,
  }) => exportStream(
    encrypted: Stream.value(encryptedBytes),
    suggestedName: suggestedName,
  );
}

final class BackupFileExportFailure implements Exception {
  const BackupFileExportFailure();
  @override
  String toString() => 'Backup file saving was not confirmed.';
}
