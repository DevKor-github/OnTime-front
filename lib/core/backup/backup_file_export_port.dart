import 'package:flutter/services.dart';

enum BackupFileExportReceipt { saved, cancelled }

/// A receipt contains no user-selected path or persistent document permission.
abstract interface class BackupFileExportPort {
  Future<BackupFileExportReceipt> export({
    required Uint8List encryptedBytes,
    required String suggestedName,
  });
}

final class NativeBackupFileExportPort implements BackupFileExportPort {
  const NativeBackupFileExportPort();

  static const channel = MethodChannel('ontime/backup_export');

  @override
  Future<BackupFileExportReceipt> export({
    required Uint8List encryptedBytes,
    required String suggestedName,
  }) async {
    final result = await channel.invokeMethod<String>('export', {
      'encryptedBytes': encryptedBytes,
      'suggestedName': suggestedName,
    });
    return switch (result) {
      'saved' => BackupFileExportReceipt.saved,
      'cancelled' => BackupFileExportReceipt.cancelled,
      _ => throw const BackupFileExportFailure(),
    };
  }
}

final class BackupFileExportFailure implements Exception {
  const BackupFileExportFailure();

  @override
  String toString() =>
      '백업 저장을 완료하지 못했습니다. 선택한 위치에 불완전한 파일이 남았는지 확인한 뒤 다시 시도해주세요.';
}
