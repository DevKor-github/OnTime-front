---
status: accepted
---

# Export a point-in-time backup snapshot

Each OnTime Backup will represent one consistent Backup Cutoff captured from the Local Data Store. Every Durable OnTime Data change committed before that cutoff is included, while later commits remain active and are deferred to a later backup. OnTime may release the database snapshot after materializing a stable export input so the user can continue editing while password-based encryption and destination writing finish; the displayed creation time remains the Backup Cutoff rather than file completion time. A backup file will be exposed as complete only after encryption, integrity verification, and writing all succeed, and a cancelled or failed export will not leave an artifact presented as a valid OnTime Backup. Reading tables independently throughout a long export or blocking all app use until the destination write completes was rejected because the former can mix states and the latter is unnecessary once a stable snapshot exists.
