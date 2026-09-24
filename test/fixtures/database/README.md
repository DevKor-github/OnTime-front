# Historical SQLite fixtures for A08

`schema_v2.sql` was executed and emitted from actual Drift AppDatabase sources and matching generated artifacts at commit `4529d9f84e911b1ee2fbb42af09698a0c27cc9f2`, copied to `/tmp/a08-schema-baseline`. The extraction test opened `NativeDatabase.memory()`, queried `SELECT sql FROM sqlite_master WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%' ORDER BY type DESC,name`, joined DDL with semicolons and appended `PRAGMA user_version=2`. Command: `/Users/ejunpark/Library/flutter/bin/flutter test test/dump_test.dart` in the isolated temporary source copy; execution log `/tmp/a08-historical-dump.log`.

`schema_v1.sql` was **reconstructed from that frozen v2 DDL**, removing the four recurring tables and five schedule columns introduced by commit `f0877d1df9aa62528f360f5ee1d3bbb095e2f691`, and setting `user_version=1`. It was checked against the source definitions at `ccc6272bde15937a87dd577157b3330593718759` with `git diff ccc6272bde15937a87dd577157b3330593718759 4529d9f84e911b1ee2fbb42af09698a0c27cc9f2 -- lib/data/tables lib/core/database/database.dart`. Other historical table definitions are unchanged. It was not emitted by running a historical v1 binary.

The migration tests populate these frozen schemas using sqlite3, close them, then open file databases through the current AppDatabase migration path. They verify v1/v2 migration, rollback, identity and protected data preservation, and future-version refusal. This is native SQLite testing, not a historical released app or device SQLCipher migration claim; D04 owns that device verification. Fixtures never derive from current schema-3 table models.

SHA-256:

- `schema_v1.sql`: `782cd3a3cfdca56c67f896a7fbdfa9791a349f77b2b65e21c7f0c0f2ce4a121d`
- `schema_v2.sql`: `a7ec3c57f1c86a58ef45c3417abe187fa4e44a0be87e3861a7182cb3ab02d7c5`
