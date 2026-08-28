---
status: accepted
---

# Preserve local data when migration fails

Local Data Store schema migrations will be atomic and will never fall back to silently deleting or recreating the database. If OnTime cannot open the encrypted store or complete a migration, it will preserve both the database and Installation Data Key and start in a restricted Recovery Mode rather than creating an empty Local Profile. Recovery Mode will not start normal product screens or background Schedule Notification processing and will offer only a startup retry, an OnTime Backup restore, or an explicit Local Data Reset. The preserved store and key may be removed only after a replacement restore succeeds or the user confirms Local Data Reset. Automatic destructive recovery was rejected because Local-only OnTime has no server from which lost records can be downloaded again. This requires a recovery startup path and transactional migration tests but makes upgrade failure non-destructive and user-controlled.
