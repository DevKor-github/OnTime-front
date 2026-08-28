import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:on_time_front/core/database/installation_key_store.dart';
import 'package:on_time_front/core/database/local_data_files.dart';

QueryExecutor openOnTimeDatabase(InstallationKeyStore keyStore) {
  return LazyDatabase(() async {
    final file = await localDatabaseFile();
    await file.parent.create(recursive: true);
    if (!await file.exists()) await file.create();
    await excludeLocalDatabaseFromPlatformBackup(file);
    final key = await keyStore.getOrCreate();
    final keyHex = key
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();

    return NativeDatabase.createInBackground(
      file,
      setup: (rawDatabase) {
        rawDatabase.execute('PRAGMA key = "x\'$keyHex\'"');
        rawDatabase.execute('PRAGMA cipher_memory_security = ON');
      },
    );
  });
}
