---
status: accepted
---

# Replace durable data on backup restore

Backup Restore will validate a complete OnTime Backup and atomically replace the installation's current durable data instead of merging records. Backups include the Local Profile, onboarding state, schedules, places, preparations, retained outcomes, and app preferences, but exclude active preparation sessions, early-start state, device identifiers, operating-system permissions, scheduled-notification registrations, caches, and logs. After a successful restore, OnTime will derive and register notifications again from restored future schedules. This avoids synchronization-style conflict rules, duplicate alarms, and partially restored profiles at the cost of requiring users to create a safety backup before replacing existing data.
