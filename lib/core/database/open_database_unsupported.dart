import 'package:drift/drift.dart';
import 'package:on_time_front/core/database/installation_key_store.dart';

QueryExecutor openOnTimeDatabase(InstallationKeyStore keyStore) {
  throw UnsupportedError('OnTime local data is supported on Android and iOS.');
}
