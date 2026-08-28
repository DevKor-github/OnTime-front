import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:on_time_front/core/database/installation_key_store.dart';

QueryExecutor openOnTimeDatabase(InstallationKeyStore keyStore) {
  return driftDatabase(
    name: 'ontime_local_dev',
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.dart.js'),
    ),
  );
}
