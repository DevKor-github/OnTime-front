import 'encrypted_database_guard.dart';
import 'recovery/pair_files.dart';
import 'recovery/store_pair.dart';
import 'package:on_time_front/core/database/initial_store_guard.dart';
import 'package:on_time_front/core/database/sqlcipher_loader.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:on_time_front/core/database/installation_key_store.dart';

QueryExecutor openOnTimeDatabase(InstallationKeyStore keyStore) {
  return LazyDatabase(() async {
    final files = await PairFiles.device();
    final pair = await files.selected();
    final file = files.database(pair);
    final state = await files.readRecord();
    if (!pair.isLegacy &&
        state?.stage != PairStage.ready &&
        state?.stage != PairStage.cancelled) {
      throw const PairAuthorityUnavailable();
    }
    if (!pair.isLegacy) await files.requireExisting(pair);
    final initial = InitialStoreGuard(
      file,
      keyStore,
      activationEvidence: files.hasEvidence,
    );
    final key = pair.isLegacy
        ? await initial.prepareOpen()
        : await files.keys.read(pair);
    final allowCreation = pair.isLegacy && await initial.allowsSchemaCreation();
    if (key == null) throw const PairAuthorityUnavailable();
    final keyHex = key
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();

    return NativeDatabase.createInBackground(
      file,
      isolateSetup: configureSqlCipherLoader,
      setup: (rawDatabase) {
        guardEncryptedDatabase(
          rawDatabase,
          keyHex,
          role: pair.isLegacy
              ? DatabaseOpenRole.legacyStartup
              : DatabaseOpenRole.activePairStartup,
          allowCreation: allowCreation,
        );
      },
    );
  });
}
