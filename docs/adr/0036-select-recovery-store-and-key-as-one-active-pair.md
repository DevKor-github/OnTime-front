---
status: accepted
---

# Select the recovery database and key as one active pair

A damaged-store Backup Restore cannot atomically replace a fixed database file and a secure-storage key in two independent systems. D02 therefore prepares and verifies a separate encrypted candidate store with its own device-bound key slot, then selects that immutable pair through a versioned, app-owned active-store manifest; a minimal recovery journal and authoritative read-back resolve interrupted activation without deleting the original pair or treating an ambiguous state as a fresh installation.

The active store epoch identifies the selected pair, while the runtime generation inside that database belongs to A09's transactional restore boundary. A normal restore changes only the database runtime generation; it does not rewrite the manifest or replace the installation key. Candidate cleanup state and its initial generation exist before activation, so the manifest selects a consistent candidate rather than coordinating a second commit.

Old material remains until the new pair has been reopened and verified after restart, then pending cleanup removes it. A committed restore is not automatically rolled back because cleanup failed. Missing or corrupt manifests with prior-manifest or in-progress evidence enter Recovery Mode instead of falling back to the legacy pair or creating an empty store. Platform flush/rename behavior and failure recovery require implementation tests; this decision does not assert power-loss durability or report D02 as implemented.

This deliberately adds bounded inactive key material and an installation-local pointer instead of overwriting the sole fixed key slot. There remains exactly one active Installation Data Key. The decision and rejected alternative were resolved in the actual D02 grill transcript in `plans/audit-2026-09-23/issues/D02.md`; file/key ownership, reset cleanup, preview currentness, and mobile acceptance remain part of that issue.
