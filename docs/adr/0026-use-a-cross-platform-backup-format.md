---
status: accepted
---

# Use a cross-platform backup format

OnTime Backup will be a versioned, platform-neutral representation that can be exported on Android and restored on iOS or exported on iOS and restored on Android. It will not copy the encrypted Drift or SQLite database file because that would couple portability to an installation key, storage engine details, and platform configuration. The encrypted backup envelope will declare its Backup Format Version, creation time, contained data categories and counts, encryption parameters, and integrity metadata. Backup Restore will decrypt, validate, migrate, and materialize all content in a staging Local Data Store before atomically replacing active data; unsupported or unrepresentable content will be rejected before mutation. The source Installation Data Key, permissions, notification identifiers, and operating-system delivery registrations will not cross the boundary and will be regenerated or reconciled by the destination installation. Same-platform raw database copying was rejected because it would not satisfy the product's portable recovery guarantee.
