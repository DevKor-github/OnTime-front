# A09 implementation preflight

Status: preparation only, 2026-09-24. A08 is still implementing and exclusively owns product files and Flutter commands. Do not start A09 product changes until A08's source freeze, final local verification, source commit and handoff. A09 #602 remains the full accepted scope; this note records current integration points, not additional approval or passed tests.

## Current evidence

- C01 source `4529d9f84e911b1ee2fbb42af09698a0c27cc9f2`, remote proof HEAD `aa2fda68fbf3ac431738de3792f5d587d35b6dda`: workflow receipts and exclusive preview validation exist. Final remote Flutter 959 tests, 88.72%, Android APK/manifest success. Actual encrypted staging and full runtime replacement remain pending.
- `BackupService._claimRestore` claims the existing `LocalDataOperationGate` before preview generation/revision validation, then increments the memory generation. `_applyRestore` cancels old alarms before its database transaction; the transaction rechecks revision, replaces rows, and imports source revision plus one. This revision is not an installation-wide monotonic epoch.
- The current candidate holds parsed data in memory. Do not call this actual encrypted staging proof.
- `PreparationWithTimeLocalDataSourceImpl` uses the `preparation_with_time_` namespace and validates SharedPreferences write/removal booleans. `EarlyStartSessionLocalDataSourceImpl` uses `early_start_session_` and still ignores removal booleans. Inventory all runtime namespaces rather than only restored schedule IDs.
- `NotificationTapRouter` currently tags receipt with the memory generation at reception. Late old OS delivery requires an installation-persistent identity, not retagging it with current generation.
- `LocalDataLifecycle.bootstrap` handles D03 reset recovery and the historical local-only cutover. Reuse the reset journal/OS owner and typed startup recovery boundaries. Do not reuse cutover's blanket preference cleanup as restore cleanup.
- A08 WIP schema 3 introduces installation-local `Users.storeIncarnation` and aggregate identities/receipt metadata, excluded from portable backup versions 1/2. Its restore path inserts a fresh profile so identity is reissued. Treat this as WIP until final source handoff. Prefer this authoritative store identity where suitable instead of introducing an independent second epoch with conflicting semantics.

## Next implementation sequence

1. Read A08's final actual transcript, ADR 0037, source manifest and final validation. Recheck current gate, receipt, writer and watch behavior from that committed source.
2. Build an explicit writer/runtime/OS ownership inventory. Separate precommit quiescence, one durable commit, postcommit cleanup and restart recovery; no timer timeout counts as native cancellation.
3. Resolve the minimal persisted cleanup marker and staging-key/path lifetime against the existing encrypted database opener and platform backup exclusion. Any new migration must follow final A08 schema, preserving v1/v2 portable backups and historical database fixtures.
4. Add behavior-first negative evidence for same-ID/fingerprint restored data reviving old runtime and late OS tap acceptance, then implement actual staging and replacement through existing C01/A15/D03 ownership.
5. Verify rollback before commit, partial completion after commit, actual file/DB reopen or host process boundaries, all old runtime namespaces, source identity, KO/EN receipt UI and complete regression. Host fixtures, native compilation and real mobile execution are distinct evidence.

No staging files, runtime cleanup, database replacement, GitHub policy changes or device actions were performed for this note. D02 damaged-database replacement, D05 input bounds and D07 template timestamps remain separately tracked dependencies; do not conceal unresolved data round-trip differences by weakening checks.
