---
status: accepted
---

# Bind schedule saves to local aggregate identities

Schedule saving uses one atomic schedule/place/preparation/revision transaction and installation-local store/aggregate identities, versions, and the last mutation receipt in schema 3, rather than a global mutation ledger. New schedule drafts additionally fence an absent target with the reviewed durable revision; this deliberately requires explicit re-review after unrelated edits so an old create cannot recreate a deleted schedule without retaining tombstones, while existing-schedule edits compare only their dependent aggregate versions. Portable backup versions 1 and 2 exclude these identities and receipts: restore/reset must issue a fresh store identity and fresh aggregate identities even if user IDs and revisions match; recurring split receipts remain on the stable series root, and mere occurrence materialization does not advance its edit version.
