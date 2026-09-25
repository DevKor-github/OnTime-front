---
status: accepted
---

# Bind schedule saves to local aggregate identities

Schedule saving uses one atomic schedule/place/preparation/revision transaction and installation-local store/aggregate identities, versions, and the last mutation receipt in schema 3, rather than a global mutation ledger. New schedule drafts additionally fence an absent target with the reviewed durable revision; this deliberately requires explicit re-review after unrelated edits so an old create cannot recreate a deleted schedule without retaining tombstones, while existing-schedule edits compare only their dependent aggregate versions. Portable backup versions 1 and 2 exclude these identities and receipts: restore/reset must issue a fresh store identity and fresh aggregate identities even if user IDs and revisions match; recurring split receipts remain on the stable series root, and mere occurrence materialization does not advance its edit version.

Default Preparation and spare time editing use the same store identity and a coherent durable revision baseline without adding a preference version column. Both values commit atomically with one durable revision; unchanged values cause no writes or dependency invalidation. Since this pair has no separate aggregate version, unrelated durable edits deliberately require an explicit reload and review. A stale draft is never silently rebased, even if its values happen to equal the latest settings. Cache refresh and current-data notification reconciliation are separate postcommit receipts; retries never repeat the preference writes. Leaving the screen does not undo a commit. Existing profile observation/startup loading and alarm reconciliation remain recovery paths; these in-memory follow-up receipts are not a new durable journal.
