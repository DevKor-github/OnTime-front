import 'dart:io';
import 'package:sqlite3/open.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';

/// Called before the first SQLite open in each isolate. Android's sqlite3
/// default loads libsqlite3, whereas our bundled library is libsqlcipher.
void configureSqlCipherLoader() {
  if (Platform.isAndroid) {
    open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
  }
}
