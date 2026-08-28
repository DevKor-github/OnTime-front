---
status: accepted
---

# Start local-only without a server import

The local-only release will not provide a one-time login or import from the legacy OnTime server. Both new and upgraded installations will create a new Local Profile and encrypted Local Data Store through onboarding. Existing Schedule persistence is remote-only, its unused local table is not an authoritative source, and local Preparation paths are incomplete; therefore the transition will not promote any legacy Drift rows or SharedPreferences values into Durable OnTime Data. It will idempotently remove Legacy Installation State, including credentials, remote caches, device delivery records, and active sessions, before onboarding, resuming cleanup if interrupted. Remote-only records and legacy local state will not carry forward or be described as recoverable; only OnTime Backups created by the local-only product will support future installation transfer. Attempting a best-effort salvage was rejected because partial caches could surface missing or incorrectly related Schedules and Preparations as trusted user data.
