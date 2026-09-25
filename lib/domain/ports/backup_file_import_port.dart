import 'dart:typed_data';
import 'package:on_time_front/domain/entities/backup_processing.dart';

abstract interface class BackupFileImportPort {
  Future<BackupImportSource?> select({BackupProcessingLease? lease});
}

/// No provider URI, path, name or persistent access grant crosses this port.
abstract interface class BackupImportSource {
  int? get declaredLength;
  Stream<Uint8List> openRead();
  Future<void> close();
}
