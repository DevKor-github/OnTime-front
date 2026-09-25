class LocalDevelopmentDatabaseFile {
  const LocalDevelopmentDatabaseFile();
}

const localDatabaseFileName = 'ontime_local_v1.sqlite';

Future<LocalDevelopmentDatabaseFile> localDatabaseFile() async =>
    const LocalDevelopmentDatabaseFile();

Future<void> excludeLocalDatabaseFromPlatformBackup(
  LocalDevelopmentDatabaseFile file,
) async {}

Future<void> deleteLocalDatabaseFiles({required bool includeLegacy}) async {}

Future<void> deleteLegacyDatabaseFiles() async {}
