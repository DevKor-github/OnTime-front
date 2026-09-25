import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const localDatabaseFileName = 'ontime_local_v1.sqlite';

Future<File> localDatabaseFile() async {
  final directory = await getApplicationSupportDirectory();
  return File(p.join(directory.path, localDatabaseFileName));
}

Future<void> excludeLocalDatabaseFromPlatformBackup(File file) async {
  if (!Platform.isIOS) return;
  const channel = MethodChannel('on_time_front/native_alarm');
  await channel.invokeMethod<void>('excludeFromBackup', {'path': file.path});
}

Future<void> deleteLocalDatabaseFiles({required bool includeLegacy}) async {
  final current = await localDatabaseFile();
  await _deleteSqliteFamily(current.path);
  if (!includeLegacy) return;

  final documents = await getApplicationDocumentsDirectory();
  for (final name in const ['my_database.sqlite', 'my_database']) {
    await _deleteSqliteFamily(p.join(documents.path, name));
  }
}

Future<void> _deleteSqliteFamily(String path) async {
  for (final suffix in const ['', '-wal', '-shm', '-journal']) {
    final file = File('$path$suffix');
    if (await file.exists()) await file.delete();
    if (await file.exists()) {
      throw FileSystemException(
        'Local database removal is unconfirmed',
        file.path,
      );
    }
  }
}
