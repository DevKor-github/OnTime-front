import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:on_time_front/core/database/installation_key_store.dart';

QueryExecutor openOnTimeDatabase(InstallationKeyStore keyStore) {
  return LazyDatabase(() async {
    final result = await WasmDatabase.open(
      databaseName: 'ontime_local_dev',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.dart.js'),
    );
    return result.resolvedExecutor;
  });
}
